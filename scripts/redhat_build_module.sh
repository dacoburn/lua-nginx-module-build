#!/bin/bash

# Get NGINX Source

# Get the installed NGINX Version
NGINX_VERSION=`nginx -V 2>&1 | grep "nginx version" | awk -F "/" '{print $2}'`
# Get the yum variant of the version
NGINX_VERSION_YUM=`rpm -qa nginx | awk 'BEGIN{FS=OFS="."}{NF--; print}'`
nginxver="nginx-$NGINX_VERSION"
OSID=`cat /etc/os-release | grep -e "^ID=" | awk -F "=" '{print $2}' | sed 's/\"//g'`
NGINX_FOLDER=$BASE_FOLDER/$nginxver
source_url=http://nginx.org/packages/centos/$RHELVER/SRPMS
normal_url=http://nginx.org/packages/centos/$RHELVER/$basearch/RPMS/

# Extra and Objects folder
EXTRA_FOLDER=$NGINX_FOLDER/extra
OBJS_FOLDER=$NGINX_FOLDER/objs

# LUA & NGINX Devel Kit locations
LUAJIT_LIB=/usr/local/lib/
LUAJIT_INC=$EXTRA_FOLDER/LuaJIT-2.0.5/src
NGX_DEVEL=$EXTRA_FOLDER/ngx_devel_kit-0.3.1rc1
LUA_MODULE=$EXTRA_FOLDER/lua-nginx-module-0.10.13
luajit_file=LuaJIT-2.0.5.tar.gz

if [ "$OSID" == "amzn" ] || [ "$OSID" == "amzn" ]; then
    # Steps for Amazon Linux
    export source_rpm=$NGINX_VERSION_YUM.src.rpm
    if [ ! -f $source_rpm ]; then
        # Install the Source RPM
        yumdownloader --source nginx
        rpm -i $source_rpm
        cp /usr/src/rpm/SOURCES/nginx-1.16.1.tar.gz ./
    fi

else
    # Steps for CentOS 6/7
    echo "[nginx]" | tee /etc/yum.repos.d/nginx.repo
    echo "name=nginx repo" | tee -a /etc/yum.repos.d/nginx.repo
    echo "baseurl=http://nginx.org/packages/mainline/centos/$RHELVER/$basearch/" | tee -a /etc/yum.repos.d/nginx.repo
    echo "gpgcheck=0" | tee -a /etc/yum.repos.d/nginx.repo
    echo "enabled=1" | tee -a /etc/yum.repos.d/nginx.repo

    echo "[nginx-src]" | tee /etc/yum.repos.d/nginx-src.repo
    echo "name=nginx repo"  | tee -a /etc/yum.repos.d/nginx-src.repo
    echo "baseurl=http://nginx.org/packages/mainline/centos/$RHELVER/SRPMS/" | tee -a /etc/yum.repos.d/nginx-src.repo
    echo "gpgcheck=0" | tee -a /etc/yum.repos.d/nginx-src.repo
    echo "enabled=1" | tee -a /etc/yum.repos.d/nginx-src.repo
    
    export source_rpm=$NGINX_VERSION_YUM.ngx.src.rpm
    if [ ! -f $source_rpm ]; then
        wget $source_url/$source_rpm
        rpm -i $source_rpm
    fi

    if [ ! -f $nginxver.tar.gz ]; then 
        cp /root/rpmbuild/SOURCES/$nginxver.tar.gz ./
    fi
fi


if [ ! -d $nginxver ]; then
    tar -zxvf $nginxver.tar.gz
fi



# Download LUA Jit
if [ ! -d $EXTRA_FOLDER ]; then
    mkdir $EXTRA_FOLDER
fi

cd $EXTRA_FOLDER

if [ ! -f $luajit_file ]; then
    wget http://luajit.org/download/LuaJIT-2.0.5.tar.gz -O $EXTRA_FOLDER/$luajit_file && \
    tar -zxvf $luajit_file
fi

# Build LUA Jit
cd $EXTRA_FOLDER/LuaJIT-2.0.5

make -j2
make install

if [ ! -f /lib64/libluajit-5.1.so.2 ]; then
    ln -s /usr/local/lib/libluajit-5.1.so.2 /lib64/libluajit-5.1.so.2
fi

cd $EXTRA_FOLDER

# Get and extract nginx devel kit
if [ ! -f v0.3.1rc1.tar.gz ]; then
    wget https://github.com/simplresty/ngx_devel_kit/archive/v0.3.1rc1.tar.gz
    tar -zxvf v0.3.1rc1.tar.gz
fi

# Get and extract the lua framework source

if [ ! -f v0.10.13.tar.gz ]; then
    wget https://github.com/openresty/lua-nginx-module/archive/v0.10.13.tar.gz
    tar -zxvf v0.10.13.tar.gz
fi

cd $NGINX_FOLDER

# Configure NGINX based on the build flags for the installed nginx
echo "#!/bin/bash" > build.sh
echo "./configure \\" >> build.sh
nginx -V 2>&1 | grep "configure arguments" | awk -F 'arguments:' '{print $2 " \\"}' >> build.sh
echo " --add-dynamic-module=$NGX_DEVEL \\" >> build.sh
echo " --add-dynamic-module=$LUA_MODULE" >> build.sh

chmod +x build.sh
./build.sh

# | sed -e '$ ! s/$/ \\/g'
# you can change the parallism number 2 below to fit the number of spare CPU cores in your
# machine.
make -j2 modules

RET=$?
if [ $RET -eq 0 ]; then
    mkdir -p $OUTPUT_FOLDER
    echo "Successful Build"
    cp $OBJS_FOLDER/ndk_http_module.so $OUTPUT_FOLDER/ndk_http_module.so
    
    NDK=$?
    if [ $NDK -ne 0 ]; then
        echo "Failed to copy ndk_http_module.so, likely build failure"
        exit 1
    fi
    
    cp $OBJS_FOLDER/ngx_http_lua_module.so $OUTPUT_FOLDER/ngx_http_lua_module.so

    NGX=$?
    if [ $NGX -ne 0 ]; then
        echo "Failed to copy ngx_http_lua_module.so, likely build failure"
        exit 1
    fi
    sed -i '/^pid/a load_module \/output\/ngx_http_lua_module.so;' /etc/nginx/nginx.conf
    sed -i '/^pid/a load_module \/output\/ndk_http_module.so;' /etc/nginx/nginx.conf
    nginx -t
    if [ $? -ne 0 ]; then
        echo "Module did not work with NGINX"
        exit 1
    fi

    cd $OUTPUT_FOLDER
    tar -czvf $OUTPUT_FOLDER/$nginxver-lua-module.tar.gz *.so
    echo "Tar file saved at $OUTPUT_FOLDER/$nginxver-lua-module.tar.gz"


else
    echo "Failed Build"
    exit 1
fi
