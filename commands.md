- `docker run --rm -d --name forex -v $(pwd)/logs:/workdir/logs -v $(pwd)/Tester:/workdir/Tester -p 8000:8000 forex`
- `docker build -t forex .`
- `ln -s "/Users/vova/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/Tester" ./Tester`

curl -X 'POST' \
  'http://0.0.0.0:8000/backtest_file_prepare' \
  -H 'accept: application/json' \
  -d ''

curl -X 'POST' \
  'http://0.0.0.0:8000/backtest_watch?action=status' \
  -H 'accept: application/json' \
  -d ''

for Windows 
- `docker run --rm -d --name forex -v ${pwd}/logs:/workdir/logs -v ${pwd}/Tester:/workdir/Tester -p 8000:8000 forex`
- `mklink /j "C:\Users\mtuser\Documents\github\cautious-enigma\Tester" "C:\Users\mtuser\AppData\Roaming\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075"`