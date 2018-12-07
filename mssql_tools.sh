#!/bin/bash

echo -n "Введите версию Ubuntu: "
read version

if($version -z); then
 echo "Не указана версия Ubuntu"
 exit 1
fi

curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/$version/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install mssql-tools unixodbc-dev
#проверить
#echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
#source ~/.bashrc

#если возникает ошибка terminate called after throwing an instance of 'std::runtime_error'
#apt-get install -y locales && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
