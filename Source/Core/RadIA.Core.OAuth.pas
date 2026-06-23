unit RadIA.Core.OAuth;

interface

uses
  System.SysUtils, RadIA.Core.Interfaces;

type

  { Manager orchestrating the OAuth 2.0 PKCE flow }
  TRadIAOAuthManager = class
  private
    FConfig: IRadIAConfig;
    FLoopbackServer: IRadIALoopbackServer;
    FHTTPClient: IRadIAHttpClient;
    FCodeVerifier: string;
    FCodeChallenge: string;
    FState: string;
    FProviderName: string;
    FAuthUrl: string;
    FTokenUrl: string;
    FClientId: string;
    FRedirectUri: string;
    FPort: Word;
    FOnSuccess: TProc;
    FOnError: TProc<string>;
    procedure HandleCallback(const ACode, AError: string);
    procedure ExchangeCodeForToken(const ACode: string);
    function SaveTokenResponse(const AProvider: string; const AJsonStr: string): Boolean;
    class function GenerateRandomString(const ALength: Integer): string;
  protected
    procedure OpenBrowser(const AUrl: string); virtual;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const ALoopback: IRadIALoopbackServer;
      const AHTTPClient: IRadIAHttpClient = nil
    );
    destructor Destroy; override;

    procedure StartLogin(
      const AProvider: string;
      const AAuthUrl: string;
      const ATokenUrl: string;
      const AClientId: string;
      const APort: Word;
      const AOnSuccess: TProc;
      const AOnError: TProc<string>
    );
    procedure CancelLogin;
    function RefreshAccessToken(const AProvider: string; const ATokenUrl, AClientId: string): Boolean;

    class function GenerateVerifier: string;
    class function GenerateChallenge(const AVerifier: string): string;
  end;

implementation

uses
  System.Classes, System.Hash, System.NetEncoding, System.JSON,
  System.DateUtils, Winapi.ShellAPI, Winapi.Windows, RadIA.Core.Logger,
  RadIA.Core.Container, RadIA.Core.HttpClient, System.Net.URLClient;

{ TRadIAOAuthManager }

constructor TRadIAOAuthManager.Create(
  const AConfig: IRadIAConfig;
  const ALoopback: IRadIALoopbackServer;
  const AHTTPClient: IRadIAHttpClient
);
begin
  inherited Create;
  FConfig := AConfig;
  FLoopbackServer := ALoopback;
  if Assigned(AHTTPClient) then
    FHTTPClient := AHTTPClient
  else if not TRadIAContainer.TryResolve<IRadIAHttpClient>(FHTTPClient) then
    FHTTPClient := TRadIAConcreteHttpClient.Create;
end;

destructor TRadIAOAuthManager.Destroy;
begin
  CancelLogin;
  inherited Destroy;
end;

procedure TRadIAOAuthManager.OpenBrowser(const AUrl: string);
begin
  ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
end;

procedure TRadIAOAuthManager.CancelLogin;
begin
  if Assigned(FLoopbackServer) and FLoopbackServer.IsRunning then
  begin
    FLoopbackServer.Stop;
    TLogger.Log('OAuth login flow cancelled.', 'OAuth');
  end;
end;

class function TRadIAOAuthManager.GenerateRandomString(const ALength: Integer): string;
var
  I: Integer;
  LChars: string;
begin
  LChars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  Result := '';
  for I := 1 to ALength do
    Result := Result + LChars[Random(Length(LChars)) + 1];
end;

class function TRadIAOAuthManager.GenerateVerifier: string;
var
  I: Integer;
  LChars: string;
begin
  LChars := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
  Result := '';
  for I := 1 to 64 do
    Result := Result + LChars[Random(Length(LChars)) + 1];
end;

class function TRadIAOAuthManager.GenerateChallenge(const AVerifier: string): string;
var
  LHash: TBytes;
begin
  LHash := THashSHA2.GetHashBytes(AVerifier);
  Result := TNetEncoding.Base64URL.EncodeBytesToString(LHash);
  Result := Result.Replace(#13, '').Replace(#10, '').TrimRight(['=']);
end;

procedure TRadIAOAuthManager.StartLogin(
  const AProvider: string;
  const AAuthUrl: string;
  const ATokenUrl: string;
  const AClientId: string;
  const APort: Word;
  const AOnSuccess: TProc;
  const AOnError: TProc<string>
) ;
var
  LFullAuthUrl: string;
begin
  CancelLogin;

  FProviderName := AProvider;
  FAuthUrl := AAuthUrl;
  FTokenUrl := ATokenUrl;
  FClientId := AClientId;
  FPort := APort;
  FOnSuccess := AOnSuccess;
  FOnError := AOnError;

  FRedirectUri := 'http://localhost:' + FPort.ToString + '/callback';
  FCodeVerifier := GenerateVerifier;
  FCodeChallenge := GenerateChallenge(FCodeVerifier);
  FState := GenerateRandomString(16);

  TLogger.Log('Starting OAuth login for ' + FProviderName + ' on port ' + FPort.ToString, 'OAuth');

  try
    FLoopbackServer.Start(FPort,
      procedure(const ACode: string; const AError: string)
      begin
        HandleCallback(ACode, AError);
      end);
  except
    on E: Exception do
    begin
      TLogger.Log('Failed to start local loopback server: ' + E.Message, 'OAuth');
      if Assigned(FOnError) then
        FOnError('Could not start local HTTP server: ' + E.Message);
      Exit;
    end;
  end;

  LFullAuthUrl := FAuthUrl +
    '?response_type=code' +
    '&client_id=' + TNetEncoding.URL.Encode(FClientId) +
    '&redirect_uri=' + TNetEncoding.URL.Encode(FRedirectUri) +
    '&code_challenge=' + TNetEncoding.URL.Encode(FCodeChallenge) +
    '&code_challenge_method=S256' +
    '&state=' + TNetEncoding.URL.Encode(FState);

  // For Gemini or scopes, you can append scope if needed
  if SameText(FProviderName, 'gemini') then
    LFullAuthUrl := LFullAuthUrl + '&scope=' + TNetEncoding.URL.Encode(
      'https://www.googleapis.com/auth/generative-language.tuning');

  TLogger.Log('Opening system browser: ' + LFullAuthUrl, 'OAuth');
  OpenBrowser(LFullAuthUrl);
end;

procedure TRadIAOAuthManager.HandleCallback(const ACode, AError: string);
begin
  // Stop server immediately to release the port
  if Assigned(FLoopbackServer) then
    FLoopbackServer.Stop;

  if not AError.IsEmpty then
  begin
    TLogger.Log('OAuth callback returned error: ' + AError, 'OAuth');
    if Assigned(FOnError) then
      FOnError(AError);
    Exit;
  end;

  if ACode.IsEmpty then
  begin
    TLogger.Log('OAuth callback returned empty authorization code.', 'OAuth');
    if Assigned(FOnError) then
      FOnError('No authorization code received.');
    Exit;
  end;

  TLogger.Log('Authorization code received, exchanging for token...', 'OAuth');
  // Run asynchronously or directly? Loopback server callbacks might run in secondary threads,
  // so we delegate the rest of the flow
  TThread.CreateAnonymousThread(
    procedure
    begin
      ExchangeCodeForToken(ACode);
    end).Start;
end;

function TRadIAOAuthManager.SaveTokenResponse(const AProvider: string; const AJsonStr: string): Boolean;
var
  LJSON: TJSONObject;
  LAccessToken: string;
  LRefreshToken: string;
  LExpiresIn: Integer;
begin
  Result := False;
  LJSON := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  if not Assigned(LJSON) then
    Exit;
  try
    LAccessToken := LJSON.GetValue<string>('access_token', '');
    LRefreshToken := LJSON.GetValue<string>('refresh_token', '');
    LExpiresIn := LJSON.GetValue<Integer>('expires_in', 0);

    if LAccessToken.IsEmpty then
      Exit;

    FConfig.SetOAuthAccessToken(AProvider, LAccessToken);
    if not LRefreshToken.IsEmpty then
      FConfig.SetOAuthRefreshToken(AProvider, LRefreshToken);

    if LExpiresIn > 0 then
      FConfig.SetOAuthTokenExpiry(AProvider, IncSecond(Now, LExpiresIn))
    else
      FConfig.SetOAuthTokenExpiry(AProvider, 0);

    FConfig.Save;
    Result := True;
  finally
    LJSON.Free;
  end;
end;

procedure TRadIAOAuthManager.ExchangeCodeForToken(const ACode: string);
var
  LHeaders: TNetHeaders;
  LRequestBody: string;
  LResponseJson: string;
begin
  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Content-Type', 'application/x-www-form-urlencoded');

  LRequestBody := 'client_id=' + TNetEncoding.URL.Encode(FClientId) +
                  '&grant_type=authorization_code' +
                  '&code=' + TNetEncoding.URL.Encode(ACode) +
                  '&redirect_uri=' + TNetEncoding.URL.Encode(FRedirectUri) +
                  '&code_verifier=' + TNetEncoding.URL.Encode(FCodeVerifier);

  try
    LResponseJson := FHTTPClient.Post(FTokenUrl, LHeaders, LRequestBody);
    if SaveTokenResponse(FProviderName, LResponseJson) then
    begin
      TLogger.Log('OAuth token exchange completed successfully.', 'OAuth');
      if Assigned(FOnSuccess) then
        FOnSuccess;
    end
    else
    begin
      if Assigned(FOnError) then
        FOnError('Token response did not contain access_token.');
    end;
  except
    on E: ERadIAHttpException do
    begin
      TLogger.Log(Format('HTTP Exception during token exchange: %d - %s', [E.StatusCode, E.Message]), 'OAuth');
      if Assigned(FOnError) then
        FOnError('Token exchange failed with HTTP error: ' + E.StatusCode.ToString);
    end;
    on E: Exception do
    begin
      TLogger.Log('Exception during token exchange: ' + E.Message, 'OAuth');
      if Assigned(FOnError) then
        FOnError('Token exchange failed: ' + E.Message);
    end;
  end;
end;

function TRadIAOAuthManager.RefreshAccessToken(const AProvider: string; const ATokenUrl, AClientId: string): Boolean;
var
  LHeaders: TNetHeaders;
  LRequestBody: string;
  LRefreshToken: string;
  LResponseJson: string;
begin
  Result := False;
  LRefreshToken := FConfig.GetOAuthRefreshToken(AProvider);
  if LRefreshToken.IsEmpty then
  begin
    TLogger.Log('No refresh token found for ' + AProvider, 'OAuth');
    Exit;
  end;

  TLogger.Log('Refreshing access token for ' + AProvider, 'OAuth');
  SetLength(LHeaders, 1);
  LHeaders[0] := TNetHeader.Create('Content-Type', 'application/x-www-form-urlencoded');

  LRequestBody := 'client_id=' + TNetEncoding.URL.Encode(AClientId) +
                  '&grant_type=refresh_token' +
                  '&refresh_token=' + TNetEncoding.URL.Encode(LRefreshToken);

  try
    LResponseJson := FHTTPClient.Post(ATokenUrl, LHeaders, LRequestBody);
    Result := SaveTokenResponse(AProvider, LResponseJson);
    if Result then
      TLogger.Log('OAuth token refresh completed successfully.', 'OAuth');
  except
    on E: Exception do
    begin
      TLogger.Log('Failed to refresh token: ' + E.Message, 'OAuth');
    end;
  end;
end;

end.
