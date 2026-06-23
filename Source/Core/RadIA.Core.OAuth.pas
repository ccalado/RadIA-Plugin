unit RadIA.Core.OAuth;

interface

uses
  System.SysUtils, System.Classes, RadIA.Core.Interfaces;

type
  { Callback function for loopback server events }
  TLoopbackCallback = reference to procedure(const ACode: string; const AError: string);

  { Interface defining the local loopback HTTP server for OAuth callbacks }
  IRadIALoopbackServer = interface
    ['{E27C9482-1D5B-4C6C-81AB-C096BA6277FF}']
    procedure Start(const APort: Word; const ACallback: TLoopbackCallback);
    procedure Stop;
    function GetActivePort: Word;
    function IsRunning: Boolean;
  end;

  { Manager orchestrating the OAuth 2.0 PKCE flow }
  TRadIAOAuthManager = class
  private
    FConfig: IRadIAConfig;
    FLoopbackServer: IRadIALoopbackServer;
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
    class function GenerateRandomString(const ALength: Integer): string;
  protected
    procedure OpenBrowser(const AUrl: string); virtual;
  public
    constructor Create(const AConfig: IRadIAConfig; const ALoopback: IRadIALoopbackServer);
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
  System.Hash, System.NetEncoding, System.Net.HttpClient, System.JSON,
  System.DateUtils, Winapi.ShellAPI, Winapi.Windows, RadIA.Core.Logger;

{ TRadIAOAuthManager }

constructor TRadIAOAuthManager.Create(const AConfig: IRadIAConfig; const ALoopback: IRadIALoopbackServer);
begin
  inherited Create;
  FConfig := AConfig;
  FLoopbackServer := ALoopback;
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
    LFullAuthUrl := LFullAuthUrl + '&scope=' + TNetEncoding.URL.Encode('https://www.googleapis.com/auth/generative-language.tuning');

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

procedure TRadIAOAuthManager.ExchangeCodeForToken(const ACode: string);
var
  LClient: THTTPClient;
  LParams: TStringList;
  LResponse: IHTTPResponse;
  LJSON: TJSONObject;
  LAccessToken: string;
  LRefreshToken: string;
  LExpiresIn: Integer;
begin
  LClient := THTTPClient.Create;
  LParams := TStringList.Create;
  try
    LParams.AddPair('client_id', FClientId);
    LParams.AddPair('grant_type', 'authorization_code');
    LParams.AddPair('code', ACode);
    LParams.AddPair('redirect_uri', FRedirectUri);
    LParams.AddPair('code_verifier', FCodeVerifier);

    try
      LResponse := LClient.Post(FTokenUrl, LParams);
      TLogger.Log('Token exchange response code: ' + LResponse.StatusCode.ToString, 'OAuth');

      if LResponse.StatusCode = 200 then
      begin
        LJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
        if Assigned(LJSON) then
        begin
          try
            LAccessToken := LJSON.GetValue<string>('access_token', '');
            LRefreshToken := LJSON.GetValue<string>('refresh_token', '');
            LExpiresIn := LJSON.GetValue<Integer>('expires_in', 0);

            if LAccessToken.IsEmpty then
            begin
              if Assigned(FOnError) then
                FOnError('Token response did not contain access_token.');
              Exit;
            end;

            FConfig.SetOAuthAccessToken(FProviderName, LAccessToken);
            if not LRefreshToken.IsEmpty then
              FConfig.SetOAuthRefreshToken(FProviderName, LRefreshToken);

            if LExpiresIn > 0 then
              FConfig.SetOAuthTokenExpiry(FProviderName, IncSecond(Now, LExpiresIn))
            else
              FConfig.SetOAuthTokenExpiry(FProviderName, 0);

            FConfig.Save;

            TLogger.Log('OAuth token exchange completed successfully.', 'OAuth');

            if Assigned(FOnSuccess) then
              FOnSuccess;
          finally
            LJSON.Free;
          end;
        end
        else
        begin
          if Assigned(FOnError) then
            FOnError('Failed to parse token response JSON.');
        end;
      end;
    except
      on E: Exception do
      begin
        TLogger.Log('Exception during token exchange: ' + E.Message, 'OAuth');
        if Assigned(FOnError) then
          FOnError('Token exchange failed: ' + E.Message);
      end;
    end;
  finally
    LParams.Free;
    LClient.Free;
  end;
end;

function TRadIAOAuthManager.RefreshAccessToken(const AProvider: string; const ATokenUrl, AClientId: string): Boolean;
var
  LClient: THTTPClient;
  LParams: TStringList;
  LResponse: IHTTPResponse;
  LRefreshToken: string;
  LJSON: TJSONObject;
  LAccessToken: string;
  LNewRefreshToken: string;
  LExpiresIn: Integer;
begin
  Result := False;
  LRefreshToken := FConfig.GetOAuthRefreshToken(AProvider);
  if LRefreshToken.IsEmpty then
  begin
    TLogger.Log('No refresh token found for ' + AProvider, 'OAuth');
    Exit;
  end;

  TLogger.Log('Refreshing access token for ' + AProvider, 'OAuth');
  LClient := THTTPClient.Create;
  LParams := TStringList.Create;
  try
    LParams.AddPair('client_id', AClientId);
    LParams.AddPair('grant_type', 'refresh_token');
    LParams.AddPair('refresh_token', LRefreshToken);

    try
      LResponse := LClient.Post(ATokenUrl, LParams);
      TLogger.Log('Refresh token response code: ' + LResponse.StatusCode.ToString, 'OAuth');

      if LResponse.StatusCode = 200 then
      begin
        LJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
        if Assigned(LJSON) then
        begin
          try
            LAccessToken := LJSON.GetValue<string>('access_token', '');
            LNewRefreshToken := LJSON.GetValue<string>('refresh_token', '');
            LExpiresIn := LJSON.GetValue<Integer>('expires_in', 0);

            if not LAccessToken.IsEmpty then
            begin
              FConfig.SetOAuthAccessToken(AProvider, LAccessToken);
              if not LNewRefreshToken.IsEmpty then
                FConfig.SetOAuthRefreshToken(AProvider, LNewRefreshToken);

              if LExpiresIn > 0 then
                FConfig.SetOAuthTokenExpiry(AProvider, IncSecond(Now, LExpiresIn))
              else
                FConfig.SetOAuthTokenExpiry(AProvider, 0);

              FConfig.Save;
              Result := True;
              TLogger.Log('OAuth token refresh completed successfully.', 'OAuth');
            end;
          finally
            LJSON.Free;
          end;
        end;
      end;
    except
      on E: Exception do
      begin
        TLogger.Log('Failed to refresh token: ' + E.Message, 'OAuth');
      end;
    end;
  finally
    LParams.Free;
    LClient.Free;
  end;
end;

end.
