unit Unit1;

interface

uses
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, uObjPoolUnit, utils_queues,
  utils_threadinfo, utils_safeLogger, Vcl.ExtCtrls, System.Threading;

type
  TTaskParams = record
    TaskCount: integer;
    Counter: integer;
  end;

  PTaskParams = ^TTaskParams;

  TForm1 = class(TForm)
    mmo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    Panel1: TPanel;
    lbl_wait: TLabel;
    lbl_mntsize: TLabel;
    lbl_poolsize: TLabel;
    tmr1: TTimer;
    lbl_used: TLabel;
    Timer1: TTimer;
    Button3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure tmr1Timer(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    FPool: TObjPool;
    fstoped: boolean;
    function onNewObject: TObject;
    procedure onStatus(const pvStatus:String);
    procedure runtask1(var pvTask: ITask; var pvParams: PTaskParams);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var
  lvObj: TObject;
begin
  fstoped := false;
  while not fstoped do
  begin
    lvObj := FPool.getObject();
    if lvObj = nil then
    begin
      sfLogger.logMessage('排队队伍达到上限，丧失资格。');
      exit;
    end;
    sfLogger.logMessage('正在获取对象:' + inttostr(TLabel(lvObj).tag));
    // TLabel(lvObj).tag:=timer1.tag;
    sleep(Random(50));
    sfLogger.logMessage('正在归还对象:' + inttostr(TLabel(lvObj).tag));
    FPool.returnObject(lvObj);
    Application.ProcessMessages;
  end;
end;

procedure TForm1.runtask1(var pvTask: ITask; var pvParams: PTaskParams);
var
  lvParams: PTaskParams;
begin
  lvParams := pvParams;
  pvTask := TTask.Run(
    procedure
    var
      lvObj: TObject;
      j: integer;
      lvCurThrdID: THandle;
    begin
      lvCurThrdID := tthread.CurrentThread.ThreadID;
      with Form1 do
      begin
        while (lvParams.Counter < lvParams.TaskCount) and not fstoped do
        begin
          AtomicIncrement(lvParams^.Counter);
          j := lvParams^.Counter;
          lvObj := FPool.getObject(lvCurThrdID);
          if lvObj = nil then
          begin
            sfLogger.logMessage('排队队伍达到上限，丧失资格。');
            continue;
          end;
         sfLogger.logMessage('借出' + inttostr(j));
         sleep(Random(500));
         FPool.returnObject(lvObj);
         sfLogger.logMessage('归还' + inttostr(j));
        end;
      end;
    end);
end;

procedure TForm1.Button2Click(Sender: TObject);
const
  c_counter: integer = 10000;
var
  i: integer;
  lvTask: array of ITask;
  lvCpus: integer;
  lvParams: PTaskParams;
begin
  fstoped := false;
  lvCpus := CPUCount * 50;
  setlength(lvTask, lvCpus);
  sfLogger.logMessage('正在测试多线程...');
  new(lvParams);
  lvParams.Counter := 0;
  lvParams.TaskCount := c_counter;
  for i := 0 to lvCpus - 1 do
  begin
    sleep(1);
    runtask1(lvTask[i], lvParams);
  end;
  Button2.Enabled := false;
  TTask.Run(
    procedure()
    begin
      TTask.WaitForAll(lvTask);
      Dispose(lvParams);
      sfLogger.logMessage('多线程测试完毕...');
      FPool.Clear;
      tthread.Synchronize(nil,
        procedure
        begin
          Button2.Enabled := true;
        end);
    end);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  fstoped := true;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  InitalizeForThreadInfo;
  sfLogger.setAppender(TStringsAppender.Create(mmo1.Lines));
  sfLogger.AppendInMainThread := true;
  TStringsAppender(sfLogger.Appender).AddThreadINfo := true;
  FPool := TObjPool.Create(10);
  FPool.OnNewObjectEvent := onNewObject;
  FPool.setUIThreadID(tthread.CurrentThread.ThreadID);
  FPool.WaitQueueSize := 100;
  FPool.OnStatusEvent:=onStatus;
  fstoped := false;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Timer1.Enabled := false;
  while FPool.getPoolSize <> FPool.Count do
  begin
    Application.ProcessMessages;
    sleep(20);
  end;
  FPool.Destroy;
end;

function TForm1.onNewObject: TObject;
begin
  result := TLabel.Create(self);
  TLabel(result).name := 'lbl_' + inttostr(integer(result));
  TLabel(result).tag := FPool.mntSize;
  sfLogger.logMessage('onNewObject call.');
end;

procedure TForm1.onStatus(const pvStatus: String);
begin
  sfLogger.logMessage(pvStatus);
end;

procedure TForm1.tmr1Timer(Sender: TObject);
begin
  lbl_wait.caption := format('当前等待队列:%d', [FPool.CurWaitCounter]);
  lbl_mntsize.caption := format('当前对象池管理对象数:%d', [FPool.mntSize]);
  lbl_poolsize.caption := format('当前对象池可用对象数:%d', [FPool.getPoolSize]);
  lbl_used.caption := format('当前已在使用对象数:%d', [FPool.mntSize - FPool.getPoolSize]);
end;

end.
