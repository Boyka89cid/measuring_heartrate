import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';
import 'chart.dart';

Future<void> main() async
{
  //final
  runApp(MaterialApp(title: 'PPG',home: Home(),theme: ThemeData(brightness: Brightness.light)));
}

class Home extends StatefulWidget
{
  @override
  State<StatefulWidget> createState()=>HomeView();
}
class HomeView extends State<Home>
{
  bool _clicked=false;
  CameraController? _cameraController;
  List<SensorValue> list=[];
  bool _processing=false;
  double _bpm=0;
  double _alpha=.4;

  Future<void> _initController() async //initializing controller for camera.
  {
    try
    {
      List cameras=await availableCameras();
      _cameraController=CameraController(cameras.first, ResolutionPreset.high);
      await _cameraController?.initialize();

      Future.delayed(Duration(milliseconds: 500)).then((value)
      {
        //_cameraController?.setFlashMode(FlashMode.always);
        _cameraController!.setFlashMode(FlashMode.torch);
      });
      _cameraController?.startImageStream((image)
      {
        if(!_processing)
          setState(() {
            _processing=true;
          });
        scanImage(image);
      });
    }catch(e){print(e);}
  }

  scanImage(CameraImage image)
  {
    double avg=image.planes.first.bytes.reduce((value, element) => value+element)/image.planes.first.bytes.length;
    if(list.length>=50)
      list.removeAt(0);
    setState(()
    {
      list.add(SensorValue(DateTime.now(), avg));
    });
    Future.delayed(Duration(milliseconds: 1000~/30)).then((value) {
      setState(() {
        _processing=false;
      });
    });
  }
  updateBPM() async
  {
    List<SensorValue> _values;
    double _avg;
    int _n;
    double _m;
    double _threshold;
    int _counter;
    int _previous;
    while (_clicked)
    {
      _values = List.from(list);
      _avg = 0;
      _n = _values.length;
      _m = 0;
      _values.forEach((SensorValue value)
      {
        _avg += value.value / _n;
        if (value.value > _m) _m = value.value;
      });
      _threshold = (_m + _avg) / 2;
      _bpm = 0;
      _counter = 0;
      _previous = 0;
      for (int i = 1; i < _n; i++)
      {
        if (_values[i - 1].value < _threshold && _values[i].value > _threshold)
        {
          if (_previous != 0)
          {
            _counter++;
            _bpm += 60000 / (_values[i].time.millisecondsSinceEpoch - _previous);
          }
          _previous = _values[i].time.millisecondsSinceEpoch;
        }
      }
      if (_counter > 0)
      {
        _bpm = _bpm / _counter;
        setState(() {_bpm = (1 - _alpha) * _bpm + _alpha * _bpm;});
      }
      await Future.delayed(Duration(milliseconds: (1000 * 50 / 30).round()));
    }
  }
  disposeCameraController()
  {
    _cameraController?.dispose();
    _cameraController=null;
  }

  unClick()
  {
    _initController().then((value)
    {
      Wakelock.enable();
      setState(() {
        _clicked=true;
        _processing=false;
      });
      updateBPM();
    });
  }
  clicked()
  {
    Wakelock.enable();
    disposeCameraController();
    setState(() {
      _clicked=false;
      _processing=false;
    });
  }
  @override
  void dispose()
  {
    super.dispose();
    disposeCameraController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: _cameraController == null ? Container() : CameraPreview(_cameraController!)
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        (_bpm > 30 && _bpm < 120 ? _bpm.round().toString() : "--"),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: IconButton(
                  icon: Icon(_clicked? Icons.favorite : Icons.favorite_border), color: Colors.blue, iconSize: 128,
                  onPressed: ()
                  {
                    if (_clicked)
                      clicked();
                    else
                      unClick();
                  }
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10)),
                    color: Colors.brown),
                child: Chart(list),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
