unit RadIA.Tests.IndyLoopback;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces;

type
  [TestFixture]
  TTestIndyLoopback = class
  private
    FServer: IRadIALoopbackServer;
    FCallbackCalled: Boolean;
    FReceivedCode: string;
    FReceivedError: string;
    procedure LoopbackCallback(const ACode, AError: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestServerStartStopAndIsRunning;
    [Test]
    procedure TestGetActivePort;
    [Test]
    procedure TestSuccessfulCallbackRequest;
    [Test]
    procedure TestFailureCallbackRequest;
    [Test]
    procedure TestNotFoundRequest;
    [Test]
    procedure TestSuccessfulAuthCallbackRequest;
  end;

implementation

uses
  System.SysUtils, System.Net.HttpClient, RadIA.Core.IndyLoopback;

{ TTestIndyLoopback }

procedure TTestIndyLoopback.Setup;
begin
  FServer := TRadIAIndyLoopbackServer.Create;
  FCallbackCalled := False;
  FReceivedCode := '';
  FReceivedError := '';
end;

procedure TTestIndyLoopback.TearDown;
begin
  if Assigned(FServer) then
    FServer.Stop;
  FServer := nil;
end;

procedure TTestIndyLoopback.LoopbackCallback(const ACode, AError: string);
begin
  FCallbackCalled := True;
  FReceivedCode := ACode;
  FReceivedError := AError;
end;

procedure TTestIndyLoopback.TestServerStartStopAndIsRunning;
begin
  Assert.IsFalse(FServer.IsRunning);
  FServer.Start(61234, LoopbackCallback);
  Assert.IsTrue(FServer.IsRunning);
  FServer.Stop;
  Assert.IsFalse(FServer.IsRunning);
end;

procedure TTestIndyLoopback.TestGetActivePort;
begin
  FServer.Start(61235, LoopbackCallback);
  Assert.AreEqual<Word>(61235, FServer.GetActivePort);
end;

procedure TTestIndyLoopback.TestSuccessfulCallbackRequest;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  FServer.Start(61236, LoopbackCallback);
  Assert.IsTrue(FServer.IsRunning);

  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get('http://127.0.0.1:61236/callback?code=my-success-code');
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContentAsString.Contains('Successful!'));

    Assert.IsTrue(FCallbackCalled);
    Assert.AreEqual('my-success-code', FReceivedCode);
    Assert.IsEmpty(FReceivedError);
  finally
    LClient.Free;
  end;
end;

procedure TTestIndyLoopback.TestFailureCallbackRequest;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  FServer.Start(61237, LoopbackCallback);
  Assert.IsTrue(FServer.IsRunning);

  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get('http://127.0.0.1:61237/callback?error=my-custom-error');
    Assert.AreEqual(400, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContentAsString.Contains('Failed'));

    Assert.IsTrue(FCallbackCalled);
    Assert.IsEmpty(FReceivedCode);
    Assert.AreEqual('my-custom-error', FReceivedError);
  finally
    LClient.Free;
  end;
end;

procedure TTestIndyLoopback.TestNotFoundRequest;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  FServer.Start(61238, LoopbackCallback);
  Assert.IsTrue(FServer.IsRunning);

  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get('http://127.0.0.1:61238/invalid-url');
    Assert.AreEqual(404, LResponse.StatusCode);
    Assert.IsFalse(FCallbackCalled);
  finally
    LClient.Free;
  end;
end;

procedure TTestIndyLoopback.TestSuccessfulAuthCallbackRequest;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
begin
  FServer.Start(61239, LoopbackCallback);
  Assert.IsTrue(FServer.IsRunning);

  LClient := THTTPClient.Create;
  try
    LResponse := LClient.Get('http://127.0.0.1:61239/auth/callback?code=my-auth-code');
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.IsTrue(LResponse.ContentAsString.Contains('Successful!'));

    Assert.IsTrue(FCallbackCalled);
    Assert.AreEqual('my-auth-code', FReceivedCode);
    Assert.IsEmpty(FReceivedError);
  finally
    LClient.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestIndyLoopback);

end.
