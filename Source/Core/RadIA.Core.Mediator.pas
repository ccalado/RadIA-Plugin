unit RadIA.Core.Mediator;

{ Implements the Mediator pattern to decouple IDE integration components
  (EditorHook, MessageViewHook) from the UI layer (ChatFrame, DockableForm).

  Replaces the mutable global procedure variables previously declared in
  RadIA.Core.Types, eliminating accidental overrides and enabling future
  support for multiple chat sessions.

  Usage:
    - UI layer registers handlers via TRadIAMediator.Instance.RegisterXxx
    - Integration layer fires events via TRadIAMediator.Instance.RequestXxx
}

interface

uses  RadIA.Core.Interfaces;

type
  TRadIAMediator = class(TInterfacedObject, IRadIAMediator)
  private
    FOnRequestPrompt: TOnRequestPromptProc;
    FOnRequestDiff: TOnRequestDiffProc;
    FAutoReplaceTarget: string;
    class var FInstance: TRadIAMediator;

    constructor CreatePrivate;
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    class function Instance: TRadIAMediator;
    class destructor Destroy;

    { Registration (called by UI layer on startup) }
    procedure RegisterPromptHandler(const AHandler: TOnRequestPromptProc);
    procedure RegisterDiffHandler(const AHandler: TOnRequestDiffProc);

    { Dispatch (called by integration layer) }
    procedure RequestPrompt(const APrompt: string; const AOpenChat: Boolean);
    procedure RequestDiff(const AOriginalCode: string; const AReplaceWholeBuffer: Boolean = False);

    { Unregister (called on teardown) }
    procedure UnregisterPromptHandler;
    procedure UnregisterDiffHandler;

    property AutoReplaceTarget: string read FAutoReplaceTarget write FAutoReplaceTarget;
  end;

implementation


uses
  System.SysUtils;

{ TRadIAMediator }

constructor TRadIAMediator.CreatePrivate;
begin
  inherited Create;
  FOnRequestPrompt := nil;
  FOnRequestDiff   := nil;
  FAutoReplaceTarget := '';
end;

function TRadIAMediator._AddRef: Integer;
begin
  Result := -1;
end;

function TRadIAMediator._Release: Integer;
begin
  Result := -1;
end;

class function TRadIAMediator.Instance: TRadIAMediator;
begin
  if not Assigned(FInstance) then
    FInstance := TRadIAMediator.CreatePrivate;
  Result := FInstance;
end;

class destructor TRadIAMediator.Destroy;
begin
  FreeAndNil(FInstance);
end;

procedure TRadIAMediator.RegisterPromptHandler(const AHandler: TOnRequestPromptProc);
begin
  FOnRequestPrompt := AHandler;
end;

procedure TRadIAMediator.RegisterDiffHandler(const AHandler: TOnRequestDiffProc);
begin
  FOnRequestDiff := AHandler;
end;

procedure TRadIAMediator.UnregisterPromptHandler;
begin
  FOnRequestPrompt := nil;
end;

procedure TRadIAMediator.UnregisterDiffHandler;
begin
  FOnRequestDiff := nil;
end;

procedure TRadIAMediator.RequestPrompt(const APrompt: string; const AOpenChat: Boolean);
begin
  if Assigned(FOnRequestPrompt) then
    FOnRequestPrompt(APrompt, AOpenChat);
end;

procedure TRadIAMediator.RequestDiff(const AOriginalCode: string; const AReplaceWholeBuffer: Boolean);
begin
  if Assigned(FOnRequestDiff) then
    FOnRequestDiff(AOriginalCode, AReplaceWholeBuffer);
end;

end.
