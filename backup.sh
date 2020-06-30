
#!/bin/bash
# /opt/scripts/backup.sh

BACKUP_DIR='/srv/backup/'
BACKUP_SERV='192.168.42.78'
BACKUP_SERV_PORT='22'

die() {
        echo "$*" >&2
        exit 2
}

warn() {
        echo "$*" >&1
}

check_service() {

        declare -a service_list=("httpd" "mysqld")

        stat=0

        for i in "${service_list[@]}"; do

                spid=$(pgrep -x $i)

                if [[ -z $spid ]]; then
                        stat+=1
                        warn "$i is not working..."
                fi

        done

        if [[ "$stat" -gt "0" ]]; then
                die "Program has been killed!"
        fi

}

db_backup() {

        db_backup_dir="$BACKUP_DIR/db"

        date=$(date +%Y%m%d_%H-%M)

        dumpname="all_db.-$date.sql"

        if [[ ! -d $db_backup_dir ]]; then
                mkdir $db_backup_dir || die "$db_backup_dir couldnt created"
        fi

        mysqldump -A -C -x > $db_backup_dir/$dumpname 2> /dev/null || die "$db_backup_dir/$dumpname couldnt get the dump"

        if [[ -f $db_backup_dir/$dumpname ]]; then
                gzip $db_backup_dir/$dumpname || die "$db_backup_dir/$dumpname gzip has been failed!"
        fi
}

wp_backup() {
        wp_dir='/var/www/html'
        
        date=$(date +%Y%m%d_%H-%M)

        wp_backup_dir="$BACKUP_DIR/wp"

        compress="$(rpm -qa bzip2)"

        if [[ ! -d $wp_backup_dir ]]; then
                mkdir $wp_backup_dir || die "$wp_backup_dir  couldnt created."
        fi

        cp -a $wp_dir $wp_backup_dir/wordpress || die "$wp_dir dizini $wp_backup_dir/wordpress dizinine kopyalanamadı."

        if [[ -d $wp_backup_dir ]]; then

                if [[ ! -z $compress ]]; then
                        tar -cjf ${wp_backup_dir}/wordpress-$date.tar.bz2 $wp_backup_dir/wordpress >/dev/null 2>&1 || die "${wp_backup_dir}/wordpress-$date.tar.bz2  couldnt created."

                else
                        tar -czf ${wp_backup_dir}/wordpress-$date.tar.gz $wp_backup_dir/wordpress >/dev/null 2>&1 || die "${wp_backup_dir}/wordpress-$date.tar.gz  couldnt created."
                fi

                rm -rf $wp_backup_dir/wordpress
        fi
}

httpd_backup() {

        apache_conf_dir='/etc/httpd/conf'

        apache_backup_dir="$BACKUP_DIR/apache"

        date=$(date +%Y%m%d_%H-%M)

        if [[ ! -d $apache_backup_dir ]]; then
                mkdir $apache_backup_dir || die "$apache_backup_dir  couldnt created."
        fi

        tar -czf $apache_backup_dir/apcahe-$date.tar.gz $apache_conf_dir >/dev/null 2>&1 || die "$apache_backup_dir/apache-$date.tar.gz couldnt created..."
}

sync_all() {

        rsync -z $BACKUP_SERV $BACKUP_SERV_PORT >/dev/null 2>&1 || die "$BACKUP_SERV_PORT portu $BACKUP_SERV üzerinde kapalı."

        tar -czf $BACKUP_DIR/all.tar.gz $BACKUP_DIR/apache $BACKUP_DIR/wp $BACKUP_DIR/db >/dev/null 2>&1 || die "$BACKUP_DIR/all.tar.gz  couldnt created."

        if [[ -e $BACKUP_DIR/all.tar.gz ]]; then

                rsync -az $BACKUP_DIR/all.tar.gz $BACKUP_SERV:$BACKUP_DIR || die "$BACKUP_SERV için sync işlemi başarısız oldu."

        fi

}

main() {

        if [[ ! -d $BACKUP_DIR ]]; then
                mkdir $BACKUP_DIR 2>/dev/null || die "$BACKUP_DIR  couldnt created."
        fi

        warn "$BACKUP_DIR is exist. Keep going..."

        check_service
        db_backup
        wp_backup
        httpd_backup
        sync_all

}

if [[ $EUID == 0 ]]; then
        main 
else
        die "$0 bro, go and get your brother ;) Root access needed! "
fi
