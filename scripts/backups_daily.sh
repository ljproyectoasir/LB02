#!/bin/bash

declare -a ORIGENES
declare -a DESTINOS
declare -a NAME_BBDD

# Dias que se almacenan los backups
NUM_DIAS=7

# Origenes del backup (array)
ORIGENES=( /etc/init.d/ /etc/ha.d/ /etc/haproxy/ /etc/nagios-nrpe/ /etc/network/interfaces /etc/resolv.conf /var/log/ /root/scripts/ )

# Destinos del backup (array) dentro de /backups/daily/
DESTINOS=( servicios hearbeat haproxy nrpe conf-ip resolver logs scripts )

# Copia de base de datos
USER_BBDD=""
PASS_BBDD=""
ALL_DUMP_MYSQL="no"
DUMP_MYSQL="no"
NAME_BBDD=()

# Copia remota a backup01 (varys)
COPY_REMOTE_1='yes'

# Copia remota a backup02 (baelish)
COPY_REMOTE_2='yes'

# Datos para la copia remota, usuario para la conexion, origen y destino, IPs o DNS de los hosts de backups
USER_SYNC='root'
ORIGEN='/backups/daily/*.tar.gz'
DESTINO='/backups/daily/lb02/'
IPBACKUP1='varys.got'
IPBACKUP2='baelish.ddns.net'


############################################################################################################
############################################################################################################
############################################################################################################

# Nombre del backup del dia
DIA=`date +%d`
MES=`date +%m`
ANIO=`date +%Y`
DATE=$ANIO-$MES-$DIA

# Añade a un array los nombres de los bakups si existen
declare -a FILE
FILE=$(ls -r /backups/daily/*.tar.gz 2> /dev/null)
CONT=0

# Comprueba si los backups son legibles y elimina los backups mas viejos a partir del numero de dias de especificado
for OUT in $FILE ; do
        CONT=$((CONT+1))
        if [ -r $OUT ]; then
                if [[ $CONT -ge $NUM_DIAS ]]; then
                        rm $OUT
                        fi
                else
                        echo $DATE" - Error en backup "$CONT" "$OUT >> /var/log/error_backups_$DATE
                        fi
done

# Comprueba si hay por lo menos tantos backups como numero de backups especificado
if [[ $CONT -lt $NUM_DIAS  ]]; then
        echo $DATE" - Faltan backups, solo hay "$CONT >> /var/log/error_backups_$DATE
fi

# Si no existe ningun backups crea un directorio vacio y un fichero en blanco (para comprobar que la compresion y la sincronizacion funcionan)
NEW=$(ls -r /backups/daily/ | head -1)
if [ -z $NEW ]; then
        mkdir -p /backups/daily/2000-01-01
        echo "Compresion ok" > /backups/daily/2000-01-01.tar.gz
        NEW="2000-01-01"
fi

# Comprueba si el directorio del ultimo backup es una carpeta antes de comprimirlo, borra el backups despues de comprimirlo y crea un nuevo directorio para almacenar el backup del dia
if [ -d /backups/daily/$NEW ]; then
        cd /backups/daily/
        tar -cvzf /backups/daily/$NEW.tar.gz ${NEW} > /dev/null 2> /dev/null
        rm -rf /backups/daily/$NEW
        mkdir -p /backups/daily/$DATE
        else
                echo $DATE" - No existe el backup del dia "$DATE >> /var/log/error_backups_$DATE
                fi

# Copia de todas las bases de datos
if [ $ALL_DUMP_MYSQL == "yes" ];then
        mysqldump -u $USER_BBDD --password=$PASS_BBDD -A > /backups/daily/$DATE/all_dump_mysql.sql 2> /dev/null
fi

# Copias de las bases de datos indicadas
CONT=${#NAME_BBDD[@]}
if [ $DUMP_MYSQL == "yes" ];then
        for (( i=0 ; i<$CONT ; i=i+1 )); do
                mysqldump -u $USER_BBDD --password=$PASS_BBDD -B $NAME_BBDD  > /backups/daily/$DATE/dump_mysql_$NAME_BBDD.sql
        done
fi

# Copia los directorios de origenes a los destinos en /backups/daily/
CONT=${#ORIGENES[@]}
for (( i=0 ; i<$CONT ; i=i+1 )); do
        rsync -a ${ORIGENES[i]} /backups/daily/$DATE/${DESTINOS[i]} 2> /dev/null
done

# Modifica los permisos de los backups para que solo pueda leer y escribir root (el usuario que ejecuta el script)
chmod 600 -R /backups

# Comprime el backup actual si hay copia remota.
if [ $COPY_REMOTE_1 == 'yes' ] || [ $COPY_REMOTE_2 == 'yes' ];then
        tar -cvzf /backups/daily/$DATE.tar.gz ${DATE} > /dev/null 2> /dev/null
        chmod 600 /backups/daily/$DATE.tar.gz
fi

# Sincroniza todos los backups con el host backup01
if [ $COPY_REMOTE_1 == 'yes' ];then
        rsync --delete -ae ssh $ORIGEN $USER_SYNC@$IPBACKUP1:$DESTINO 2> /dev/null
fi

# Sincroniza todos los backups con el host backup00
if [ $COPY_REMOTE_2 == 'yes' ];then
        rsync --delete -ae ssh $ORIGEN $USER_SYNC@$IPBACKUP2:$DESTINO 2> /dev/null
fi

# Si ha habido copia remota se elimina el backup del dia comprimido
if [ $COPY_REMOTE_1 == 'yes' ] || [ $COPY_REMOTE_2 == 'yes' ];then
        rm /backups/daily/$DATE.tar.gz 2> /dev/null
fi


