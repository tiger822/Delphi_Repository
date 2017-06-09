unit uObjPoolUnit;

interface

{
  通用的对象池
  create by rocklee, 9/Jun/2017
  QQ:1927368378
  应用例子：
  FPool := TObjPool.Create(10);  //定义一个最大可以容纳10个对象的缓冲对象池
  FPool.OnNewObjectEvent := onNewObject; //定义新建对象的事件
  FPool.setUIThreadID(tthread.CurrentThread.ThreadID); //设置主线程的ThreadID
  FPool.WaitQueueSize := 100; //排队等待的最大上限
  FPool.OnStatusEvent:=onStatus; //status输出
  ...
  var lvObj:Tobject;
  lvObj := FPool.getObject(); //从池中获得对象
  ...
  FPool.returnObject(lvObj); //归还对象

}
uses
  classes, System.Contnrs, forms, sysutils,SyncObjs;

type
  TOnNewObjectEvent = function(): Tobject of object;
  TOnStatusEvent = procedure(const pvStatus: String) of object;

  TObjPool = class(TQueue)
  private
    /// <summary>
    /// 缓冲池大小
    /// </summary>
    fCapacity: Cardinal;
    fSize: Cardinal;
    fUIThreadID: THandle;
    fOnNewObjectEvent: TOnNewObjectEvent;
    fWaitCounter: integer;
    fWaitQueueSize: integer;
    fOnStatusEvent: TOnStatusEvent;
    fLockObj: integer;
    fLock:TCriticalSection;
    function innerPopItem(): Tobject;
    procedure doStatus(const pvStatus: STring);
  public
    procedure Lock;
    procedure UnLock;
    /// <summary>
    /// 当池空时等待的队列最大数，若超过等待最大数时会直接返回失败
    /// </summary>
    property WaitQueueSize: integer read fWaitQueueSize write fWaitQueueSize;
    /// <summary>
    /// 从对象池中获得对象，如果池为空时，会调用OnNewObjectEvent新建对象，
    ///
    /// </summary>
    function getObject(pvCurThreadID: THandle = 0): Tobject; virtual;
    /// <summary>
    /// 归还对象
    /// </summary>
    procedure returnObject(pvObject: Tobject); virtual;
    /// <summary>
    /// 当前池内与借出的对象总共多少
    /// </summary>
    property MntSize: Cardinal read fSize;
    /// <summary>
    /// 当前等待队列需求量
    /// </summary>
    property CurWaitCounter: integer read fWaitCounter;
    /// <summary>
    /// 获得当前池里对象多少
    /// </summary>
    function getPoolSize: integer;
    property OnStatusEvent: TOnStatusEvent read fOnStatusEvent write fOnStatusEvent;
    procedure Clear;
    procedure setUIThreadID(pvThreadID: THandle);
    constructor Create(pvCapacity: Cardinal);
    destructor destroy; override;
    property OnNewObjectEvent: TOnNewObjectEvent read fOnNewObjectEvent
      write fOnNewObjectEvent;

  end;

implementation

procedure SpinLock(var Target: integer);
begin
  while AtomicCmpExchange(Target, 1, 0) <> 0 do
  begin
{$IFDEF SPINLOCK_SLEEP}
    Sleep(1); // 1 对比0 (线程越多，速度越平均)
{$ENDIF}
  end;
end;

procedure SpinUnLock(var Target: integer);
begin
  if AtomicCmpExchange(Target, 0, 1) <> 1 then
  begin
    Assert(False, 'SpinUnLock::AtomicCmpExchange(Target, 0, 1) <> 1');
  end;
end;

{ TObjPool }

procedure TObjPool.Clear;
var
  lvObj: Pointer;
  lvCC:integer;
begin
  // 检查借出去的是否全都归还
  doStatus(Format('管理对象数:%d,池中对象数%d',[self.MntSize,count]));
  Assert(self.Count = fSize, format('还有%d个对象借出而没归还', [MntSize - self.Count]));
  lvCC:=0;
  repeat
    lvObj := innerPopItem();
    if lvObj<>nil then begin
        TObject(lvObj).Destroy;
        INC(lvCC);
    end;
  until lvObj=nil;
  fSize:=0;
  doStatus(format('销毁%d对象',[lvCC]));
  inherited;
end;

constructor TObjPool.Create(pvCapacity: Cardinal);
begin
  inherited Create;
  fLock:=TCriticalSection.Create;
  fSize := 0;
  fWaitCounter := 0;
  fCapacity := pvCapacity;
  fUIThreadID := 0;
  fLockObj := 0;
  fOnNewObjectEvent := nil;
  fOnStatusEvent := nil;
end;

destructor TObjPool.destroy;
begin
  Clear;
  fLock.Destroy;
  inherited;
end;

procedure TObjPool.doStatus(const pvStatus: STring);
begin
  if (@fOnStatusEvent = nil) then
    exit;
  fOnStatusEvent(pvStatus);
end;

function TObjPool.getObject(pvCurThreadID: THandle = 0): Tobject;
var
  lvCurTheadID: THandle;
begin
  Assert(@fOnNewObjectEvent <> nil, 'OnNewObectEvent is not assigned!');
  result := innerPopItem();
  if result <> nil then
  begin
    exit;
  end;
  if fWaitCounter > fWaitQueueSize then
  begin // 前面排队数量超过指定上限则退出
    doStatus('前面排队数量超过指定上限，退出...');
    exit;
  end;

  if fSize = fCapacity then
  begin // 已经达到上限，等待
    // sfLogger.logMessage('排队等候...');
    doStatus('排队等候...');
    // InterlockedIncrement(fWaitCounter);
    AtomicIncrement(fWaitCounter);
    if pvCurThreadID <> 0 then
      lvCurTheadID := pvCurThreadID
    else
      lvCurTheadID := TThread.CurrentThread.ThreadID;
    while (result = nil) do
    begin
      if (lvCurTheadID = fUIThreadID) then
      begin
        Application.ProcessMessages;
      end;
      Sleep(1);
      result := innerPopItem();
    end;
    AtomicDecrement(fWaitCounter);
    exit;
  end;
  Lock;
  try
    result := fOnNewObjectEvent();
  finally
    UnLock;
  end;
  AtomicIncrement(fSize);
end;

function TObjPool.getPoolSize: integer;
begin
  result := Count;
end;

function TObjPool.innerPopItem: Tobject;
begin
  Lock;
  try
    if Count=0 then begin
       result:=nil;
       exit;
    end;
    result := Tobject(self.PopItem());
  finally
    UnLock;
  end;
end;

procedure TObjPool.Lock;
begin
  SpinLock(fLockObj);
  //fLock.Enter;
end;
procedure TObjPool.UnLock;
begin
  SpinUnLock(fLockObj);
  //fLock.Leave;
end;

procedure TObjPool.returnObject(pvObject: Tobject);
begin
  Lock;
  try
    self.PushItem(pvObject);
  finally
    UnLock;
  end;
end;

procedure TObjPool.setUIThreadID(pvThreadID: THandle);
begin
  fUIThreadID := pvThreadID;
end;


end.
