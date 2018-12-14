array_networks=(
 'X.X.X.0-255'
)

array_exc=(
 'X.X.X.X'
)

server_cms="SERVERNAME" #FQDN or NetBIOS
sql_cms=$(<script.sql)
tmp_file_CMS="/tmp/.sql.servers"
tmp_file_1C="/tmp/.1c.servers"
tmp_script="/tmp/.script.sql"

for network in ${array_networks[@]}
do

 #результат nmap поместим в массив, конструкция var=$(nmap ...) возвращает псевдомассив, в нем недоступен unset
 mapfile -t array_dns < <(nmap --script=dns-service-discovery -p 53 --open $network -oG - | awk '/Up$/{print $2}')

 #исключим неиспользуемые DNS
 index=0
 for ip_dns in ${array_dns[@]}
 do
  for ip_exc in ${array_exc[@]}
  do
   if [ $ip_dns = $ip_exc ]; then
    unset array_dns[$index]
   fi
  done
 let index++
 done

 dns=$(echo $array_dns | tr  '\n' ',' | sed 's/.$//')
 #DNS_space=$(echo $exhaust | tr  '\n' ' ' | sed 's/.$//')

 #nmap -n -T4 -p1433 -sS --open $network --dns-servers $DNS -oG - | awk '/Up$/{print $2}' | xargs -L1 nmap -p 1433 --script ms-sql-instance --script-args="path=$path/sql_servers.log, dns=$DNS_space" $1
 #array_IP=(`nmap -n -T4 -p1433 -sS --open $network --dns-servers $DNS -oG - | awk '/Up$/{print $2}'`) #| xargs -L1 -I{} sqlcmd -S {} -E -Q 'SET NOCOUNT ON; SELECT name FROM sys.databases' -y0 -s '|' -o ms.txt

 mapfile -t array_ip < <(nmap -n -T4 -p1433 -sS --open $network --dns-servers $dns -oG - | awk '/Up$/{print $2}')
 index=0
 for ip in ${array_ip[@]}
 do
  result=$(nslookup -query=ptr $ip $dns | awk -F= '{printf $2}' | sed 's/.$//' | sed '/^$/d' |sed 's/ //')
  if [ -z $result ]; then
   unset array_ip[$index]
  fi
  let index++
 done

 #сгенерируем файл sql_servers.log со списком SQL инстансов (см. ms-sql-instanse.nse)
 echo ${array_ip[@]} | xargs -L1 nmap -p 1433 --script ms-sql-instance --script-args="path_CMS=$tmp_file_CMS, path_1C=$tmp_file_1C, dns=$dns" $1 > /dev/null
 array_instance=$(cat $tmp_file_CMS)
 #echo ${array_instance[@]}

 for ip in ${array_ip[@]}
 do
   fqdn=$(nslookup -query=ptr $ip $dns | awk -F= '{printf toupper($2)}' | sed 's/.$//' | sed '/^$/d' |sed 's/ //')
   domain=$(IFS='.' read -r -a array <<< $fqdn; echo "${array[1]}.${array[2]}")
   #по ip адресам SQL серверов получим SQL инстансы
   for ip_ins in ${array_instance[@]}
   do
    server_name_port=$(echo $ip_ins | grep $fqdn) #здесь хранится FQDN\SQL_instance,port
    if [ -n "$server_name_port" ]; then
     #NetBIOS имя
     server_name=$(IFS=',' read -r -a array_1 <<< $server_name_port; IFS='.' read -r -a array_2 <<< ${array_1[@]}; echo ${array_2[0]})
     instance_name=$(IFS='\\' read -r -a array_1 <<< $server_name_port; IFS="," read -r -a array_2 <<< ${array_1[2]}; echo ${array_2[0]})
     if [ -n "$instance_name" ]; then
      server_name=$(echo $server_name"\\\\"$instance_name )
     fi
     echo $sql_cms | sed -e "s/_server_name/$server_name_port/g" | sed -e "s/_server_group_name/$domain/g" | sed -e "s/s_name/$server_name/g"   >> $tmp_script
     sqlcmd -S $server_cms -d msdb -E -i $tmp_script -y0
     rm $tmp_script
    fi
   done
 done

done

/opt/pgpro/1c-10/bin/psql -h localhost -U robot -w -d DBA -c "copy _InfoRg18 from '$tmp_file_1C' (delimiter('|'));" #truncate table _InfoRg18;
rm $tmp_file_CMS $tmp_file_1C
