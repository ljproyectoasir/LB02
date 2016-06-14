#!/bin/bash

USER='root'
ORIGEN='/backups/daily/*.tar.gz'
DESTINO='/backups/lb02/daily/'
IPBACKUP1='192.168.1.202'
IPBACKUP2='104.196.127.49'

rsync --delete -ae ssh $ORIGEN $USER@$IPBACKUP1:$DESTINO
rsync --delete -ae ssh $ORIGEN $USER@$IPBACKUP2:$DESTINO






