program RadIATests;

{$DEFINE TESTS}
{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  
  // Production Units
  RadIA.Core.Types in '..\Source\Core\RadIA.Core.Types.pas',
  RadIA.Core.Interfaces in '..\Source\Core\RadIA.Core.Interfaces.pas',
  RadIA.Core.ChatMessage in '..\Source\Core\RadIA.Core.ChatMessage.pas',
  RadIA.Core.Container in '..\Source\Core\RadIA.Core.Container.pas',
  RadIA.Core.Logger in '..\Source\Core\RadIA.Core.Logger.pas',
  RadIA.Core.ConfigDefaults in '..\Source\Core\RadIA.Core.ConfigDefaults.pas',
  RadIA.Core.CredentialProtector in '..\Source\Core\RadIA.Core.CredentialProtector.pas',
  RadIA.Core.Config in '..\Source\Core\RadIA.Core.Config.pas',
  RadIA.Core.SettingsStorage in '..\Source\Core\RadIA.Core.SettingsStorage.pas',
  RadIA.Core.ProviderRegistry in '..\Source\Core\RadIA.Core.ProviderRegistry.pas',
  RadIA.Core.Cache in '..\Source\Core\RadIA.Core.Cache.pas',
  RadIA.Core.Service in '..\Source\Core\RadIA.Core.Service.pas',
  RadIA.Core.PromptHistory in '..\Source\Core\RadIA.Core.PromptHistory.pas',
  RadIA.Core.TokenUsage in '..\Source\Core\RadIA.Core.TokenUsage.pas',
  RadIA.Core.ConversationExporter in '..\Source\Core\RadIA.Core.ConversationExporter.pas',
  RadIA.Core.PromptTemplates in '..\Source\Core\RadIA.Core.PromptTemplates.pas',
  RadIA.Core.ProjectContext in '..\Source\Core\RadIA.Core.ProjectContext.pas',
  RadIA.Core.Sessions in '..\Source\Core\RadIA.Core.Sessions.pas',
  RadIA.Core.DTO.Generator in '..\Source\Core\RadIA.Core.DTO.Generator.pas',
  RadIA.Core.ProjectGenerator in '..\Source\Core\RadIA.Core.ProjectGenerator.pas',
  RadIA.Core.HttpClient in '..\Source\Core\RadIA.Core.HttpClient.pas',
  RadIA.Core.ErrorDecoder in '..\Source\Core\RadIA.Core.ErrorDecoder.pas',
  RadIA.Core.Localizer in '..\Source\Core\RadIA.Core.Localizer.pas',
  RadIA.OTA.Adapter in '..\Source\Integration\RadIA.OTA.Adapter.pas',
  RadIA.OTA.Helper in '..\Source\Integration\RadIA.OTA.Helper.pas',
  RadIA.OTA.EditorHook in '..\Source\Integration\RadIA.OTA.EditorHook.pas',
  RadIA.OTA.ContextParser in '..\Source\Integration\RadIA.OTA.ContextParser.pas',
  RadIA.OTA.MessageViewHook in '..\Source\Integration\RadIA.OTA.MessageViewHook.pas',
  RadIA.Core.Mediator in '..\Source\Core\RadIA.Core.Mediator.pas',
  RadIA.Core.OAuth in '..\Source\Core\RadIA.Core.OAuth.pas',
  RadIA.Core.IndyLoopback in '..\Source\Core\RadIA.Core.IndyLoopback.pas',
  RadIA.Provider.Streaming in '..\Source\Providers\RadIA.Provider.Streaming.pas',
  RadIA.Provider.Base in '..\Source\Providers\RadIA.Provider.Base.pas',
  RadIA.Provider.Gemini in '..\Source\Providers\RadIA.Provider.Gemini.pas',
  RadIA.Provider.OpenAI in '..\Source\Providers\RadIA.Provider.OpenAI.pas',
  RadIA.Provider.Claude in '..\Source\Providers\RadIA.Provider.Claude.pas',
  RadIA.Provider.Ollama in '..\Source\Providers\RadIA.Provider.Ollama.pas',
  RadIA.Provider.DeepSeek in '..\Source\Providers\RadIA.Provider.DeepSeek.pas',
  RadIA.Provider.Groq in '..\Source\Providers\RadIA.Provider.Groq.pas',
  RadIA.Provider.OpenRouter in '..\Source\Providers\RadIA.Provider.OpenRouter.pas',
  RadIA.Provider.Generic in '..\Source\Providers\RadIA.Provider.Generic.pas',
  RadIA.Provider.LMStudio in '..\Source\Providers\RadIA.Provider.LMStudio.pas',
  RadIA.Provider.AzureOpenAI in '..\Source\Providers\RadIA.Provider.AzureOpenAI.pas',
  RadIA.Provider.Qwen in '..\Source\Providers\RadIA.Provider.Qwen.pas',
  RadIA.Provider.Mistral in '..\Source\Providers\RadIA.Provider.Mistral.pas',
  RadIA.Core.AwsSigner in '..\Source\Core\RadIA.Core.AwsSigner.pas',
  RadIA.Core.TextNormalizer in '..\Source\Core\RadIA.Core.TextNormalizer.pas',
  RadIA.Provider.GithubCopilot in '..\Source\Providers\RadIA.Provider.GithubCopilot.pas',
  RadIA.Provider.Bedrock in '..\Source\Providers\RadIA.Provider.Bedrock.pas',
  RadIA.UI.ChatPresenter in '..\Source\UI\RadIA.UI.ChatPresenter.pas',
  RadIA.UI.ConfigPresenter in '..\Source\UI\RadIA.UI.ConfigPresenter.pas',
  
  // Test Suites
  RadIA.Tests.Config in 'Source\RadIA.Tests.Config.pas',
  RadIA.Tests.EditorHook in 'Source\RadIA.Tests.EditorHook.pas',
  RadIA.Tests.ContextParser in 'Source\RadIA.Tests.ContextParser.pas',
  RadIA.Tests.Providers in 'Source\RadIA.Tests.Providers.pas',
  RadIA.Tests.Cache in 'Source\RadIA.Tests.Cache.pas',
  RadIA.Tests.Ollama in 'Source\RadIA.Tests.Ollama.pas',
  RadIA.Tests.Service in 'Source\RadIA.Tests.Service.pas',
  RadIA.Tests.PromptHistory in 'Source\RadIA.Tests.PromptHistory.pas',
  RadIA.Tests.TokenUsage in 'Source\RadIA.Tests.TokenUsage.pas',
  RadIA.Tests.Exporter in 'Source\RadIA.Tests.Exporter.pas',
  RadIA.Tests.Templates in 'Source\RadIA.Tests.Templates.pas',
  RadIA.Tests.ProjectContext in 'Source\RadIA.Tests.ProjectContext.pas',
  RadIA.Tests.Streaming in 'Source\RadIA.Tests.Streaming.pas',
  RadIA.Tests.ProvidersEx in 'Source\RadIA.Tests.ProvidersEx.pas',
  RadIA.Tests.Logger in 'Source\RadIA.Tests.Logger.pas',
  RadIA.Tests.Sessions in 'Source\RadIA.Tests.Sessions.pas',
  RadIA.Tests.Quota in 'Source\RadIA.Tests.Quota.pas',
  RadIA.Tests.DTOGenerator in 'Source\RadIA.Tests.DTOGenerator.pas',
  RadIA.Tests.JSONProviders in 'Source\RadIA.Tests.JSONProviders.pas',
  RadIA.Tests.Analysis in 'Source\RadIA.Tests.Analysis.pas',
  RadIA.Tests.ChatPresenter in 'Source\RadIA.Tests.ChatPresenter.pas',
  RadIA.Tests.ConfigPresenter in 'Source\RadIA.Tests.ConfigPresenter.pas',
  RadIA.Tests.ProjectGenerator in 'Source\RadIA.Tests.ProjectGenerator.pas',
  RadIA.Tests.Container in 'Source\RadIA.Tests.Container.pas',
  RadIA.Tests.Infrastructure in 'Source\RadIA.Tests.Infrastructure.pas',
  RadIA.Tests.OAuth in 'Source\RadIA.Tests.OAuth.pas',
  RadIA.Tests.IndyLoopback in 'Source\RadIA.Tests.IndyLoopback.pas',
  RadIA.Tests.TextNormalizer in 'Source\RadIA.Tests.TextNormalizer.pas',
  RadIA.Tests.AwsSigner in 'Source\RadIA.Tests.AwsSigner.pas',
  RadIA.Tests.Mediator in 'Source\RadIA.Tests.Mediator.pas',
  RadIA.Tests.ProviderBooster in 'Source\RadIA.Tests.ProviderBooster.pas',
  RadIA.Tests.CoverageBooster in 'Source\RadIA.Tests.CoverageBooster.pas',
  RadIA.Tests.OTAHelper in 'Source\RadIA.Tests.OTAHelper.pas',
  RadIA.Tests.HttpClient in 'Source\RadIA.Tests.HttpClient.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  try
    TRadIAConfig.SetBaseRegistryPath('Software\RadIA\Tests');
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);
    
    Results := Runner.Execute;
    
    if not Results.AllPassed then
      System.ExitCode := 1
    else
      System.ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 1;
    end;
  end;
end.
