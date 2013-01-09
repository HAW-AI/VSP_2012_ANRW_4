Starten einer Station:

Damit es mit start.sh gestartet werden kann, müssen die Dateien im Homeverzeichnis unter "/Desktop/VSP4" gespeichert werden oder man passt direkt in der Skriptdatei den Pfad an. Das Starten einer Station erfolgt dann über:

./start.sh <Port> <Teamnummer> <Multicastadresse> <Interface>
z.B.:
./start.sh 15011 11 "225.10.1.2" eth2

oder

java datasource.DataSource 11 25 | erl -sname sender -setcookie hallo -boot start_sasl -noshell -s station start 15011 11 25 "225.2.1.5" "172.16.1.18"
 
