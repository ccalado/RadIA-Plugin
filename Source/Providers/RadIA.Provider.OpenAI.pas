unit RadIA.Provider.OpenAI;

interface

uses  RadIA.Core.Interfaces, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAOpenAIProvider = class(TRadIAOpenAICompatibleProvider)
  private
    FThreadId: string;
    function GetCodexExecutablePath: string;
    procedure ExecuteCodexCli(const APrompt: string; const ACallback: TCompletionCallback;
      const AStreamCallback: TStreamChunkCallback; const AIsStream: Boolean);
  protected
    function GetBaseUrl: string; override;
    function GetModelsDiscoveryUrl: string; override;
    function FilterModelId(const AId: string): Boolean; override;
    function GetOAuthTokenUrl: string; override;
    function GetOAuthClientId: string; override;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;

    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.JSON, Winapi.Windows, System.Win.Registry,
  System.Generics.Collections, RadIA.Core.ProviderRegistry, RadIA.Core.Types,
  RadIA.Core.TokenUsage;

{ TRadIAOpenAIProvider }

constructor TRadIAOpenAIProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'OpenAI';
end;

function TRadIAOpenAIProvider.GetBaseUrl: string;
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
    Result := 'https://api.openai.com/v1'
  else if not FConfig.GetOpenAICustomBaseUrl.IsEmpty then
    Result := FConfig.GetOpenAICustomBaseUrl
  else
    Result := 'https://api.openai.com/v1';
end;

function TRadIAOpenAIProvider.GetAvailableModels: TArray<string>;
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
    Result := TArray<string>.Create(MODEL_OPENAI_GPT54_MINI, MODEL_OPENAI_GPT54)
  else
    Result := TArray<string>.Create(MODEL_OPENAI_GPT4O_MINI, MODEL_OPENAI_GPT4O);
end;

function TRadIAOpenAIProvider.GetName: string;
begin
  Result := 'OpenAI ChatGPT';
end;

function TRadIAOpenAIProvider.GetModelsDiscoveryUrl: string;
begin
  Result := GetBaseUrl.TrimRight(['/']) + '/models';
end;

function TRadIAOpenAIProvider.FilterModelId(const AId: string): Boolean;
begin
  { Accept only GPT and O-series reasoning models }
  Result := not AId.IsEmpty and
    (AId.StartsWith('gpt-') or AId.StartsWith('o1-') or AId.StartsWith('o3-'));
end;

function TRadIAOpenAIProvider.GetOAuthTokenUrl: string;
begin
  Result := 'https://auth.openai.com/oauth/token';
end;

function TRadIAOpenAIProvider.GetOAuthClientId: string;
begin
  Result := 'app_EMoamEEZ73f0CkXaXp7hrann';
end;



procedure TRadIAOpenAIProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    if Length(AHistory) = 0 then
      FThreadId := '';
    ExecuteCodexCli(APrompt, ACallback, nil, False);
  end
  else
  begin
    inherited SendPromptAsync(APrompt, AHistory, ACallback, ATemperature, AMaxTokens);
  end;
end;

procedure TRadIAOpenAIProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    if Length(AHistory) = 0 then
      FThreadId := '';
    ExecuteCodexCli(APrompt, nil, ACallback, True);
  end
  else
  begin
    inherited SendPromptStreamAsync(APrompt, AHistory, ACallback, ATemperature, AMaxTokens);
  end;
end;

function TRadIAOpenAIProvider.GetCodexExecutablePath: string;
var
  LReg: TRegistry;
  LKeys: TStringList;
  LKey: string;
  LPath: string;
begin
  Result := '';

  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKeyReadOnly('Software\Embarcadero\BDS') then
    begin
      LKeys := TStringList.Create;
      try
        LReg.GetKeyNames(LKeys);
        for LKey in LKeys do
        begin
          if LReg.OpenKeyReadOnly('Software\Embarcadero\BDS\' + LKey + '\Kai') then
          begin
            LPath := LReg.ReadString('CodexCLIPath');
            if not LPath.IsEmpty and FileExists(LPath) then
            begin
              Result := LPath;
              Exit;
            end;
          end;
        end;
      finally
        LKeys.Free;
      end;
    end;
  finally
    LReg.Free;
  end;

  LPath := 'C:\Program Files (x86)\Embarcadero\Kai\codex.exe';
  if FileExists(LPath) then
  begin
    Result := LPath;
    Exit;
  end;

  LPath := IncludeTrailingPathDelimiter(GetHomePath) + 'AppData\Local\OpenAI\Codex\bin\codex.exe';
  if FileExists(LPath) then
  begin
    Result := LPath;
    Exit;
  end;
end;

procedure TRadIAOpenAIProvider.ExecuteCodexCli(const APrompt: string;
  const ACallback: TCompletionCallback; const AStreamCallback: TStreamChunkCallback;
  const AIsStream: Boolean);
var
  LActiveModel: string;
  LCodexPath: string;
  LCmdLine: string;
  LThread: TThread;
begin
  LActiveModel := GetActiveModel;

  if not (SameText(LActiveModel, MODEL_OPENAI_GPT54) or
          SameText(LActiveModel, MODEL_OPENAI_GPT54_MINI)) then
  begin
    if AIsStream then
      AStreamCallback('', True, Format(
        'Error: The selected model ''%s'' is not supported in ChatGPT Plus (OAuth) mode. ' +
        'Please select a compatible model (gpt-5.4 or gpt-5.4-mini) in the chat panel.',
        [LActiveModel]))
    else
      ACallback('', Format(
        'Error: The selected model ''%s'' is not supported in ChatGPT Plus (OAuth) mode. ' +
        'Please select a compatible model (gpt-5.4 or gpt-5.4-mini) in the chat panel.',
        [LActiveModel]), False, TTokenUsage.Empty);
    Exit;
  end;

  LCodexPath := GetCodexExecutablePath;

  if LCodexPath.IsEmpty then
  begin
    if AIsStream then
      AStreamCallback('', True,
        'Error: The Codex CLI executable (codex.exe) was not found on your system. ' +
        'Please install the OpenAI Codex CLI. ' +
        '[Click here for installation instructions](https://github.com/openai/codex-cli)')
    else
      ACallback('',
        'Error: The Codex CLI executable (codex.exe) was not found on your system. ' +
        'Please install the OpenAI Codex CLI. ' +
        '[Click here for installation instructions](https://github.com/openai/codex-cli)',
        False, TTokenUsage.Empty);
    Exit;
  end;

  if FThreadId.IsEmpty then
  begin
    LCmdLine := Format(
      '"%s" -m %s exec --json --sandbox read-only --ephemeral --skip-git-repo-check -',
      [LCodexPath, LActiveModel]);
  end
  else
  begin
    LCmdLine := Format(
      '"%s" -m %s exec resume --json "%s" -',
      [LCodexPath, LActiveModel, FThreadId]);
  end;

  LThread := TThread.CreateAnonymousThread(
    procedure
    var
      LSa: TSecurityAttributes;
      LSi: TStartupInfo;
      LPi: TProcessInformation;
      LHReadOut, LHWriteOut: THandle;
      LHReadIn, LHWriteIn: THandle;
      LBuffer: array[0..4095] of Byte;
      LBytesRead, LBytesWritten: DWORD;
      LOutputStr: string;
      LLineBytes: TList<Byte>;
      I: Integer;
      LJsonStr: string;
      LJson: TJSONObject;
      LType: string;
      LItemObj: TJSONObject;
      LResponseText: string;
      LUsageObj: TJSONObject;
      LInputTokens, LOutputTokens: Integer;
      LUsage: TTokenUsage;
      LExitCode: DWORD;
      LUtf8Prompt: RawByteString;
    begin
      LSa.nLength := SizeOf(TSecurityAttributes);
      LSa.bInheritHandle := True;
      LSa.lpSecurityDescriptor := nil;

      if not CreatePipe(LHReadOut, LHWriteOut, @LSa, 0) then Exit;
      if not CreatePipe(LHReadIn, LHWriteIn, @LSa, 0) then
      begin
        CloseHandle(LHReadOut);
        CloseHandle(LHWriteOut);
        Exit;
      end;

      SetHandleInformation(LHReadOut, HANDLE_FLAG_INHERIT, 0);
      SetHandleInformation(LHWriteIn, HANDLE_FLAG_INHERIT, 0);

      ZeroMemory(@LSi, SizeOf(TStartupInfo));
      LSi.cb := SizeOf(TStartupInfo);
      LSi.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
      LSi.wShowWindow := SW_HIDE;
      LSi.hStdOutput := LHWriteOut;
      LSi.hStdError := LHWriteOut;
      LSi.hStdInput := LHReadIn;

      UniqueString(LCmdLine);

      if CreateProcess(nil, PChar(LCmdLine), nil, nil, True,
        CREATE_NO_WINDOW, nil, nil, LSi, LPi) then
      begin
        CloseHandle(LHWriteOut);
        CloseHandle(LHReadIn);

        LUtf8Prompt := UTF8Encode(APrompt);
        if Length(LUtf8Prompt) > 0 then
        begin
          WriteFile(LHWriteIn, LUtf8Prompt[1], Length(LUtf8Prompt), LBytesWritten, nil);
        end;
        CloseHandle(LHWriteIn);

        LOutputStr := '';
        LResponseText := '';
        LInputTokens := 0;
        LOutputTokens := 0;

        LLineBytes := TList<Byte>.Create;
        try
          while ReadFile(LHReadOut, LBuffer[0], SizeOf(LBuffer), LBytesRead, nil) and (LBytesRead > 0) do
          begin
            for I := 0 to LBytesRead - 1 do
            begin
              if LBuffer[I] = 10 then
              begin
                if LLineBytes.Count > 0 then
                begin
                  LJsonStr := TEncoding.UTF8.GetString(LLineBytes.ToArray).Trim;
                  LLineBytes.Clear;
                end
                else
                  LJsonStr := '';

                if not LJsonStr.IsEmpty then
                begin
                  try
                    LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
                    if Assigned(LJson) then
                    begin
                      try
                        LType := LJson.GetValue<string>('type', '');

                        if SameText(LType, 'thread.started') then
                        begin
                          FThreadId := LJson.GetValue<string>('thread_id', '');
                        end
                        else if SameText(LType, 'item.completed') then
                        begin
                          LItemObj := LJson.GetValue('item') as TJSONObject;
                          if Assigned(LItemObj) then
                          begin
                            LResponseText := LItemObj.GetValue<string>('text', '');
                          end;
                        end
                        else if SameText(LType, 'turn.completed') then
                        begin
                          LUsageObj := LJson.GetValue('usage') as TJSONObject;
                          if Assigned(LUsageObj) then
                          begin
                            LInputTokens := LUsageObj.GetValue<Integer>('input_tokens', 0);
                            LOutputTokens := LUsageObj.GetValue<Integer>('output_tokens', 0);
                          end;
                        end;
                      finally
                        LJson.Free;
                      end;
                    end;
                  except
                  end;
                end;
              end
              else if LBuffer[I] <> 13 then
              begin
                LLineBytes.Add(LBuffer[I]);
              end;
            end;
          end;

          if LLineBytes.Count > 0 then
          begin
            LJsonStr := TEncoding.UTF8.GetString(LLineBytes.ToArray).Trim;
            if not LJsonStr.IsEmpty then
            begin
              try
                LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
                if Assigned(LJson) then
                begin
                  try
                    LType := LJson.GetValue<string>('type', '');

                    if SameText(LType, 'thread.started') then
                    begin
                      FThreadId := LJson.GetValue<string>('thread_id', '');
                    end
                    else if SameText(LType, 'item.completed') then
                    begin
                      LItemObj := LJson.GetValue('item') as TJSONObject;
                      if Assigned(LItemObj) then
                      begin
                        LResponseText := LItemObj.GetValue<string>('text', '');
                      end;
                    end
                    else if SameText(LType, 'turn.completed') then
                    begin
                      LUsageObj := LJson.GetValue('usage') as TJSONObject;
                      if Assigned(LUsageObj) then
                      begin
                        LInputTokens := LUsageObj.GetValue<Integer>('input_tokens', 0);
                        LOutputTokens := LUsageObj.GetValue<Integer>('output_tokens', 0);
                      end;
                    end;
                  finally
                    LJson.Free;
                  end;
                end;
              except
              end;
            end;
          end;
        finally
          LLineBytes.Free;
        end;

        CloseHandle(LHReadOut);

        WaitForSingleObject(LPi.hProcess, INFINITE);
        GetExitCodeProcess(LPi.hProcess, LExitCode);
        CloseHandle(LPi.hProcess);
        CloseHandle(LPi.hThread);

        if LResponseText.IsEmpty then
        begin
          LResponseText := 'Error: No response generated by Codex.';
        end;

        LUsage.PromptTokens := LInputTokens;
        LUsage.CompletionTokens := LOutputTokens;
        LUsage.TotalTokens := LInputTokens + LOutputTokens;

        if not GIsShuttingDown then
        begin
          TThread.Queue(nil,
            TThreadProcedure(
              procedure
              begin
                if AIsStream then
                begin
                  AStreamCallback(LResponseText, False, '');
                  AStreamCallback('', True, '');
                end
                else
                begin
                  ACallback(LResponseText, '', True, LUsage);
                end;
              end
            )
          );
        end;
      end
      else
      begin
        CloseHandle(LHWriteOut);
        CloseHandle(LHReadOut);
        CloseHandle(LHReadIn);
        CloseHandle(LHWriteIn);

        if not GIsShuttingDown then
        begin
          TThread.Queue(nil,
            TThreadProcedure(
              procedure
              begin
                if AIsStream then
                  AStreamCallback('', True, 'Error: Failed to create the Codex process.')
                else
                  ACallback('', 'Error: Failed to create the Codex process.', False,
                    TTokenUsage.Empty);
              end
            )
          );
        end;
      end;
    end
  );

  LThread.FreeOnTerminate := True;
  LThread.Start;
end;

initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'OpenAI',
      'OpenAI ChatGPT',
      'https://api.openai.com/v1',
      True, // HasApiKey
      True, // HasCustomUrl
      [MODEL_OPENAI_GPT4O_MINI, MODEL_OPENAI_GPT4O, MODEL_OPENAI_GPT54_MINI, MODEL_OPENAI_GPT54],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAOpenAIProvider.Create(ACfg);
      end
    )
  );

end.
