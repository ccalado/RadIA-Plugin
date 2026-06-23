unit RadIA.Tests.OAuth;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces, RadIA.Core.OAuth,
  RadIA.Core.SettingsStorage;

type
  TMockLoopbackServer = class(TInterfacedObject, IRadIALoopbackServer)
  private
    FRunning: Boolean;
    FPort: Word;
    FCallback: TLoopbackCallback;
  public
    procedure Start(const APort: Word; const ACallback: TLoopbackCallback);
    procedure Stop;
    function GetActivePort: Word;
    function IsRunning: Boolean;

    property Callback: TLoopbackCallback read FCallback;
  end;

  TTestableOAuthManager = class(TRadIAOAuthManager)
  private
    FLastOpenedUrl: string;
  protected
    procedure OpenBrowser(const AUrl: string); override;
  public
    property LastOpenedUrl: string read FLastOpenedUrl;
  end;

  [TestFixture]
  TTestRadIAOAuth = class
  private
    FConfig: IRadIAConfig;
    FStorage: IRadIASettingsStorage;
    FMockServer: TMockLoopbackServer;
    FManager: TTestableOAuthManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestPKCEGeneration;
    [Test]
    procedure TestStartLoginTriggersLoopbackStartAndOpensUrl;
    [Test]
    procedure TestHandleCallbackWithError;
    [Test]
    procedure TestCancelLoginStopsServer;
  end;

implementation

uses
  System.SysUtils, RadIA.Core.Config;

{ TMockLoopbackServer }

procedure TMockLoopbackServer.Start(const APort: Word; const ACallback: TLoopbackCallback);
begin
  FPort := APort;
  FCallback := ACallback;
  FRunning := True;
end;

procedure TMockLoopbackServer.Stop;
begin
  FRunning := False;
end;

function TMockLoopbackServer.GetActivePort: Word;
begin
  Result := FPort;
end;

function TMockLoopbackServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

{ TTestableOAuthManager }

procedure TTestableOAuthManager.OpenBrowser(const AUrl: string);
begin
  FLastOpenedUrl := AUrl;
end;

{ TTestRadIAOAuth }

procedure TTestRadIAOAuth.Setup;
begin
  TRadIAConfig.SetBaseRegistryPath('Software\TestRadIAOAuth');
  FStorage := TRadIAMemorySettingsStorage.Create;
  TRadIAConfig.SetStorage(FStorage);
  FConfig := TRadIAConfig.Create;
  FConfig.Load;

  FMockServer := TMockLoopbackServer.Create;
  FManager := TTestableOAuthManager.Create(FConfig, FMockServer);
end;

procedure TTestRadIAOAuth.TearDown;
begin
  FManager.Free;
  FConfig := nil;
  FStorage := nil;
  TRadIAConfig.SetStorage(nil);
  TRadIAConfig.SetBaseRegistryPath('');
end;

procedure TTestRadIAOAuth.TestPKCEGeneration;
var
  LVerifier: string;
  LChallenge: string;
begin
  LVerifier := TRadIAOAuthManager.GenerateVerifier;
  Assert.AreEqual(64, Length(LVerifier), 'Verifier must be 64 characters long.');

  LChallenge := TRadIAOAuthManager.GenerateChallenge(LVerifier);
  Assert.IsNotEmpty(LChallenge, 'Challenge must not be empty.');
  Assert.IsFalse(LChallenge.Contains('='), 'Challenge must be Base64URL-encoded.');
end;

procedure TTestRadIAOAuth.TestStartLoginTriggersLoopbackStartAndOpensUrl;
begin
  Assert.IsFalse(FMockServer.IsRunning);

  FManager.StartLogin(
    'OpenAI',
    'https://auth.openai.com/oauth/authorize',
    'https://auth.openai.com/oauth/token',
    'radia-delphi-plugin',
    59182,
    nil,
    nil
  );

  Assert.IsTrue(FMockServer.IsRunning);
  Assert.AreEqual(Word(59182), FMockServer.GetActivePort);
  Assert.IsNotEmpty(FManager.LastOpenedUrl);
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('https://auth.openai.com/oauth/authorize'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('client_id=radia-delphi-plugin'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('redirect_uri=http%3A%2F%2Flocalhost%3A59182%2Fcallback'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('code_challenge='));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('code_challenge_method=S256'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('state='));
end;

procedure TTestRadIAOAuth.TestHandleCallbackWithError;
var
  LErrorMsg: string;
  LSuccessCalled: Boolean;
begin
  LSuccessCalled := False;
  LErrorMsg := '';

  FManager.StartLogin(
    'OpenAI',
    'https://auth.openai.com/oauth/authorize',
    'https://auth.openai.com/oauth/token',
    'radia-delphi-plugin',
    59182,
    procedure
    begin
      LSuccessCalled := True;
    end,
    procedure(AError: string)
    begin
      LErrorMsg := AError;
    end
  );

  Assert.IsTrue(FMockServer.IsRunning);
  Assert.IsTrue(Assigned(FMockServer.Callback));

  FMockServer.Callback('', 'access_denied');

  Assert.IsFalse(LSuccessCalled);
  Assert.AreEqual('access_denied', LErrorMsg);
  Assert.IsFalse(FMockServer.IsRunning);
end;

procedure TTestRadIAOAuth.TestCancelLoginStopsServer;
begin
  FManager.StartLogin(
    'OpenAI',
    'https://auth.openai.com/oauth/authorize',
    'https://auth.openai.com/oauth/token',
    'radia-delphi-plugin',
    59182,
    nil,
    nil
  );

  Assert.IsTrue(FMockServer.IsRunning);

  FManager.CancelLogin;

  Assert.IsFalse(FMockServer.IsRunning);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAOAuth);

end.
