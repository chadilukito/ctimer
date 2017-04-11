program TestTimerConsole;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  CTimer,
  syncobjs,
  SysUtils;

type
  { thus is a fake oject whose usage will be to use object methods
  }

  { TRunningThread }

  TRunningThread = class(TThread)
  private
    FTimer2: TCustomControlTimer;
    FTimer3: TCustomControlTimer;
    FTimer2StartTimes: TDateTime;
    FTimer3StartTimes: TDateTime;
    FInterval: Integer;
    FLastError: String;
    FBlockingEvent: TEvent;
    CS2: TRTLCriticalSection;

  protected
    procedure DoLog(const AText: String);
    procedure Timer2Event(const Sender: TObject);
    procedure Timer3Event(const Sender: TObject);
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    function StartTimers: Boolean;
    function StopTimers: Boolean;

    property Interval: Integer read FInterval write FInterval;
    property LastError: String read FLastError;
  end;

  { TFakeObbject }

  TFakeObbject = class(TObject)
  private
    Timer0: TCustomControlTimer;
    Timer1: TCustomControlTimer;
    FTimer0StartTimes: TDateTime;
    FTimer1StartTimes: TDateTime;
  protected
    procedure DoTimer0Event(const Sender: TObject);
    procedure DoTimer1Event(const Sender: TObject);
  public
    procedure DoLog(const AText: String);

  end;

{ TRunningThread }

constructor TRunningThread.Create;
begin
  inherited Create(True);
  FTimer2StartTimes := 0;
  FTimer3StartTimes := 0;
  FTimer2 := TCustomControlTimer.Create(nil);
  FTimer3 := TCustomControlTimer.Create(nil);
  FBlockingEvent := TEvent.Create(nil, True, True, 'threadblockingevent');
  InitCriticalSection(CS2);
  FreeOnTerminate := False;
end;

destructor TRunningThread.Destroy;
begin
  FBlockingEvent.SetEvent;
  if Assigned(FTimer2) then begin
    {$IFDEF DEBUG}
    AddLogInfo(Format('Destroying timer %d', [Index + 1]));
    {$ENDIF}
    if FTimer2.Enabled then
      FTimer2.Enabled := False;
    FTimer2.Free;
  end;
  FTimer2 := nil;
  if Assigned(FTimer3) then begin
    {$IFDEF DEBUG}
    AddLogInfo(Format('Destroying timer %d', [Index + 1]));
    {$ENDIF}
    if FTimer3.Enabled then
      FTimer3.Enabled := False;
    FTimer3.Free;
  end;
  FTimer3 := nil;
  FBlockingEvent.Free;
  DoneCriticalSection(CS2);
  inherited Destroy;
end;

procedure TRunningThread.DoLog(const AText: String);
var
  wWaitRes: TWaitResult;
begin
  system.EnterCriticalSection(CS2);
  try
    wWaitRes := FBlockingEvent.WaitFor(5000);
    if wWaitRes = wrSignaled then begin
      FBlockingEvent.ResetEvent;
      WriteLn(AText);
    end;
  finally
    FBlockingEvent.SetEvent;
    system.LeaveCriticalSection(CS2)
  end
end;

procedure TRunningThread.Execute;
begin
  while not Terminated do begin
    Sleep(50);
  end;
end;

function TRunningThread.StartTimers: Boolean;
begin
  FTimer2.Interval := FInterval;
  FTimer2.OnTimer := @Timer2Event;
  Sleep(100);
  FTimer3.Interval := FInterval;
  FTimer3.OnTimer := @Timer3Event;
  Sleep(100);
  FTimer2.Enabled := True;
  FTimer3.Enabled := True;
end;

function TRunningThread.StopTimers: Boolean;
begin
  FTimer2.Enabled := False;
  FTimer3.Enabled := False;
end;

procedure TRunningThread.Timer2Event(const Sender: TObject);
var
  wInterval: TDateTime;
begin
  wInterval := now - FTimer2StartTimes;
  DoLog(Format('threaded timer 2 time:%s', [FormatDateTime('hh:nn:ss.zzz', wInterval)]));
end;

procedure TRunningThread.Timer3Event(const Sender: TObject);
var
  wInterval: TDateTime;
begin
  wInterval := now - FTimer3StartTimes;
  DoLog(Format('threaded timer 3 time:%s', [FormatDateTime('hh:nn:ss.zzz', wInterval)]));
end;

{ TFakeObbject }

procedure TFakeObbject.DoLog(const AText: String);
begin
  WriteLn(AText)
end;

procedure TFakeObbject.DoTimer0Event(const Sender: TObject);
var
  wInterval: TDateTime;
begin
  wInterval := now - FTimer0StartTimes;
  DoLog(Format('timer 0 time:%s', [FormatDateTime('hh:nn:ss.zzz', wInterval)]));
end;

procedure TFakeObbject.DoTimer1Event(const Sender: TObject);
var
  wInterval: TDateTime;
begin
  wInterval := now - FTimer1StartTimes;
  DoLog(Format('timer 1 time:%s', [FormatDateTime('hh:nn:ss.zzz', wInterval)]));
end;

procedure usage;
begin
  writeln('usage: TestTimerConsole -h show usage'+#13#10+
          '                        -i interval');
end;

var
  Elapsed: TDateTime;
  StartTime: TDateTime;
  Index: Integer;
  LastParam: String;
  Interval: Integer;
  TH: TRunningThread;

begin
  LastParam := EmptyStr;
  for Index := 1 to Paramcount do begin
    if LastParam = EmptyStr then
      LastParam := ParamStr(Index)
    else begin
      if LastParam = '-i' then begin
        Interval := StrToIntDef(ParamStr(Index), -1);
        if Interval = -1 then begin
          WriteLn(Format('interval "%s" is not valid, 2000 assumed', [ParamStr(Index)]))
        end
      end else
      if LastParam = '-h' then begin
        usage();
        halt(1)
      end
    end
  end;
  if Interval < 1 then begin
    WriteLn('Invalid or omitted Interval, set to 2000 ms');
    Interval := 2000;
  end;
  with TFakeObbject.Create do try
    Timer0 := TCustomControlTimer.Create(nil);
    Timer0.Interval := Interval;
    Timer0.OnTimer := @DoTimer0Event;
    FTimer0StartTimes := now;
    Timer0.Enabled := True;
    Timer1 := TCustomControlTimer.Create(nil);
    Timer1.Interval := Interval;
    Timer1.OnTimer := @DoTimer1Event;
    FTimer1StartTimes := now;
    Timer1.Enabled := True;
    // launch threaded timers
    TH := TRunningThread.Create;
    TH.Interval := Interval;
    TH.StartTimers;
    StartTime := now;
    Elapsed := 0;
    while Elapsed < EncodeTime(0,1,0,0) do begin
      Sleep(5);
      Elapsed := now - StartTime
    end;
    TH.StopTimers;
    Timer0.Enabled := False;
    Timer1.Enabled := False;
  finally
    TH.Free;
    Free
  end;
end.

