#!/bin/bash
sudo nmap -T4 -p1433 -sS --open 10.201.X.X | grep -P 'Nmap scan report for' |  sed -n 's/.*(\(.*\)).*/\1/p' | \
 xargs -L1 dig +short -x | \
 xargs -L1 -I{} echo " /opt/mssql-tools/bin/sqlcmd -S {} -E -Q 'set nocount on; select name, database_id from sys.databases' -y0 -s '|' -o ms.txt"
