unit RadIA.Provider.OpenAI;

interface

uses  RadIA.Core.Interfaces, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAOpenAIProvider = class(TRadIAOpenAICompatibleProvider)
  protected
    function GetBaseUrl: string; override;
    function GetModelsDiscoveryUrl: string; override;
    function FilterModelId(const AId: string): Boolean; override;
    function GetOAuthTokenUrl: string; override;
    function GetOAuthClientId: string; override;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;

implementation

uses
  System.SysUtils, RadIA.Core.ProviderRegistry, RadIA.Core.Types;

{ TRadIAOpenAIProvider }

constructor TRadIAOpenAIProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'OpenAI';
end;

function TRadIAOpenAIProvider.GetBaseUrl: string;
begin
  if not FConfig.GetOpenAICustomBaseUrl.IsEmpty then
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
