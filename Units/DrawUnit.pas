unit DrawUnit;
 
//----------------------------------------------------------------------------//

interface                   

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GraphUnit, ExtCtrls, listOfPointersUnit, StdCtrls, Buttons, RoadUnit,
  HashUnit, Math;

type
  TForm1 = class(TForm)
    mapImage: TImage;
    BitBtn1: TBitBtn;
    Shape1: TShape;
    BitBtn2: TBitBtn;
    BitBtn3: TBitBtn;
    BitBtn4: TBitBtn;
    BitBtn5: TBitBtn;
    BitBtn6: TBitBtn;
    BitBtn7: TBitBtn;
    BitBtn8: TBitBtn;
    procedure BitBtn1Click(Sender: TObject);
    procedure mapImageMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure BitBtn4Click(Sender: TObject);
    procedure BitBtn5Click(Sender: TObject);
    procedure BitBtn6Click(Sender: TObject);
    procedure BitBtn7Click(Sender: TObject);
    procedure BitBtn8Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  STANDART_RADIUS = 0.015;
  STANDART_WIDTH = 0.01;

var
  Form1: TForm1;
  scale: real = 0.001;
  latitude0: real = 53.93;
  longitude0: real =  27.58;
  x0, y0: real;

procedure drawGraph;
function getXDecartCoordinates(longitude: real): real;
function getYDecartCoordinates(latitude: real): real;
  
//----------------------------------------------------------------------------//

implementation

{$R *.dfm}

const
  R: real = 6371;

function radToDeg(rad: real): real;
begin
  result := rad * 180.0 / pi;
end;

function degToRad(deg: real): real;
begin
  result := deg * pi / 180.0;
end;

function getLatitude(y: real): real;
begin
  result := arctan(exp(y / r)) - pi / 4.0;
  result := radToDeg(result * 2.0);
end;

function getLongitude(x: real): real;
begin
  result := radToDeg(x / R);
end;

function getXDecartCoordinates(longitude: real): real;
begin
  result := R * degToRad(longitude);
end;

function getYDecartCoordinates(latitude: real): real;
begin
  result := tan(pi / 4.0 + degToRad(latitude) / 2.0);
  result := R * ln(result);
end;

function getX(longitude: real): integer;
var
  t: real;
begin
  result := round((getXDecartCoordinates(longitude) - x0) / scale);
end;

function getY(latitude: real): integer;
begin
  result := round((y0 - getYDecartCoordinates(latitude)) / scale);
end;

procedure drawVertex(v: TVertex);
var
  x, y, r: integer;
begin
  with v do
  begin
    x := getX(longitude);
    y := getY(latitude);
    r := round(STANDART_RADIUS / scale);
  end;
  Form1.mapImage.Canvas.Pen.Width := 0;
  Form1.mapImage.Canvas.Ellipse(x - r, y - r, x + r, y + r);
end;

procedure drawRoadPart(x1, y1, x2, y2: integer);
begin
  with Form1.mapImage.Canvas do
  begin
    moveTo(x1, y1);
    lineTo(x2, y2);
  end;
end;

procedure drawRoad(list: TListOfPointers; style: TPenStyle; w: integer);
var
  it: TEltPt;
  x, y: integer;
begin
  it := list;
  Form1.mapImage.Canvas.Pen.Width := round(STANDART_WIDTH / scale) * w;
  Form1.mapImage.Canvas.Pen.Style := style;
  with TRoadVertexPt(it^.data)^ do
  begin
    x := getX(longitude);
    y := getY(latitude);
  end;
  Form1.mapImage.Canvas.moveTo(x, y);
  it := it^.next;
  while it <> nil do
  begin
    with TRoadVertexPt(it^.data)^ do
    begin
      x := getX(longitude);
      y := getY(latitude);
    end;
    with Form1.mapImage.Canvas do
    begin
      lineTo(x, y);
      moveTo(x, y);
    end;
    it := it^.next;
  end;
end;

procedure drawAllRoads(list: TListOfPointers);
var
  it: TEltPt;
begin
  it := list;
  while it <> nil do
  begin
    with TEdgePt(it^.data)^ do
      case movingType of
        car: drawRoad(road^, psSolid, 2);
        foot: drawRoad(road^, psDot, 1);
      end;
    it := it^.next;
  end;
end;

procedure drawGraph;
var
  it: TEltPt;
  v: TVertex;
  i: integer;
begin
  Form1.mapImage.Picture.Graphic := nil;
  Form1.mapImage.Canvas.Brush.Color := clRed;
  Form1.mapImage.Canvas.Pen.Color := clRed;
  for i := 0 to mapGraph.size - 1 do
  begin
    it := mapGraph.table[i];
    while it <> nil do
    begin
      v := TVertexPt(it^.data)^;
      drawVertex(v);
      drawAllRoads(v.edgesList);
      it := it^.next;
    end;
  end;
end;

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
  //scale := 1 / 150;
  drawGraph;
end;

function findClosestVertex(X, Y: Integer): TVertexPt;
var
  closestVert: TVertexPt;
  it: TEltPt;
  v, mouseV: TVertex;
  i: integer;
begin
  result := nil;
  with mouseV do
  begin
    latitude := getLatitude(-y * scale + y0);
    longitude := getLongitude(x * scale + x0);
  end;
  for i := 0 to mapGraph.size - 1 do
  begin
    it := mapGraph.table[i];
    if it = nil then continue;
    closestVert := TVertexPt(it^.data);
    while it <> nil do
    begin
      v := TVertexPt(it^.data)^;
      if psevdoDistation(v, mouseV) < psevdoDistation(closestVert^, mouseV) then
        closestVert := it^.data;
      it := it^.next;
    end;
    if result = nil then result := closestVert;
    if psevdoDistation(closestVert^, mouseV) < psevdoDistation(result^, mouseV) then
      result := closestVert;
  end;
end;

var
  start: TVertexPt;

procedure drawTheShortestWay(s, f: TVertexPt; movingTypeSet: TMovingTypeSet);
var
  it: TEltPt;
  dist: real;
  way: TListOfPointers;
begin
  if not getTheShortestWay(s, f, dist, way, movingTypeSet) then
  begin
    showMessage('���� �� ������..');
    exit;
  end;
  Form1.mapImage.Canvas.Brush.Color := clGreen;
  Form1.mapImage.Canvas.Pen.Color := clGreen;
  it := way;
  while it <> nil do
  begin
    drawRoad(TEdgePt(it^.data)^.road^, psDot, 1);
    it := it^.next;
  end;
end;

procedure drawTheShortestWayTroughSeveralPoints(point: array of TVertexPt;
  start: boolean = false; finish: boolean = false;
  movingTypeSet: TMovingTypeSet = [car, foot, plane]);
var
  it, it2: TEltPt;
  dist: real;
  way: TListOfPointers;
  exist: boolean;
begin
  exist := getTheShortestWayThroughSeveralPoints(point, dist, way, start, finish, movingTypeSet);
  if not exist then
  begin
    showMessage('���� �� ������..');
    exit;
  end;
  Form1.mapImage.Canvas.Brush.Color := clGreen;
  Form1.mapImage.Canvas.Pen.Color := clGreen;
  it2 := way;
  while it2 <> nil do
  begin
    it := TEltPt(it2^.data);
    while it <> nil do
    begin
      drawRoad(TEdgePt(it^.data)^.road^, psDot, 2);
      it := it^.next;
    end;
    it2 := it2^.next;
  end;
end;

var
  movType: TMovingType = car;
  arr: array of TVertexPt;

procedure TForm1.mapImageMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  v: TVertexPt;
begin
  //x := x - Form1.mapImage.Left;
  //y := y - Form1.mapImage.Top;
  v := findClosestVertex(x, y);
  if v = nil then exit;
  Form1.mapImage.Canvas.Brush.Color := clBlue;
  Form1.mapImage.Canvas.Pen.Color := clBlue;
  drawVertex(v^);
  SetLength(arr, length(arr) + 1);
  arr[length(arr) - 1] := v;
  //start = nil then start := v
  //else drawTheShortestWay(start, v, [movType]);
end;

procedure TForm1.BitBtn2Click(Sender: TObject);
begin
  start := nil;
  movType := car;
end;

procedure TForm1.BitBtn3Click(Sender: TObject);
begin
  start := nil;
  movType := foot;
end;

procedure TForm1.BitBtn4Click(Sender: TObject);
begin
  SetLength(arr, 0);
end;

procedure TForm1.BitBtn5Click(Sender: TObject);
begin
  drawTheShortestWayTroughSeveralPoints(arr, false, false, [movType]);
end;

procedure TForm1.BitBtn6Click(Sender: TObject);
begin
  drawTheShortestWayTroughSeveralPoints(arr, true, false, [movType]);
end;

procedure TForm1.BitBtn7Click(Sender: TObject);
begin
  drawTheShortestWayTroughSeveralPoints(arr, false, true, [movType]);
end;

procedure TForm1.BitBtn8Click(Sender: TObject);
begin
  drawTheShortestWayTroughSeveralPoints(arr, true, true, [movType]);
end;
  
//----------------------------------------------------------------------------//

end.
