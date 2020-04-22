#!/bin/sh

#Pin the version to the desired one
BASE_VERSION=`nginx -V 2>&1 | grep "nginx version" | awk -F "/" '{print $2}' | awk -F " " '{print $1}'`
VERSION=`dpkg -s nginx | grep Version | awk '{print $2}'`
NGINX_FOLDER=$BASE_FOLDER/nginx-$BASE_VERSION
EXTRA_FOLDER=$NGINX_FOLDER/extra
OBJS_FOLDER=$NGINX_FOLDER/objs
LUAJIT_VERSION="2.0.5"
NGX_DEVEL_VER="v0.3.1rc1"
LUA_VER=v0.10.13

# tell nginx's config where to find supporting modules
LUAJIT_LIB=/usr/local/lib/libluajit-5.1.so.2.0.5
LUAJIT_INC=$EXTRA_FOLDER/LuaJIT-2.0.5/src
NGX_DEVEL=$EXTRA_FOLDER/ngx_devel_kit-0.3.1rc1
LUA_MODULE=$EXTRA_FOLDER/lua-nginx-module-0.10.13
OSINFO=`cat /etc/os-release  | grep -e "^NAME=" | awk -F "\"" '{print $2}'`

if [ "$OSINFO" != "Ubuntu" ]; then
    # Weird thing had to do for Debian 9
    if [ ! -d /build/nginx-DhOtPd ]; then
    	mkdir -p /build/nginx-DhOtPd
    fi

    # For some reason you have to get the source for this module
    # and put in this location...
    cd /build/nginx-DhOtPd
    apt-get source libnginx-mod-http-auth-pam 
fi
# Now we can go back to normal...
cd $BASE_FOLDER

    apt-get source nginx=$VERSION



if [ ! -d "$EXTRA_FOLDER" ]; then
    echo "Making Extra Folder: $EXTRA_FOLDER"
	mkdir -p $EXTRA_FOLDER
fi

cd $EXTRA_FOLDER

# Get LuaJIT
# If you update the version of LuaJIT from this one you'll need to update the paths in the CD and the LUAJIT_INC
if [ ! -f LuaJIT-$LUAJIT_VERSION.tar.gz ]; then
	wget http://luajit.org/download/LuaJIT-$LUAJIT_VERSION.tar.gz
fi
tar -zxvf LuaJIT-$LUAJIT_VERSION.tar.gz

# Make and Install LuaJIT
cd $EXTRA_FOLDER/LuaJIT-$LUAJIT_VERSION/
make -j2
make install

ln -s $LUAJIT_LIB /usr/lib/
ldconfig

# Back to extra folder
cd $EXTRA_FOLDER/

# Get ngx_devel_kit
if [ ! -f $NGX_DEVEL_VER.tar.gz ]; then
	wget https://github.com/simplresty/ngx_devel_kit/archive/$NGX_DEVEL_VER.tar.gz
fi
tar -zxvf $NGX_DEVEL_VER.tar.gz

# Get OpenResty (LUA)

if [ ! -f $LUA_VER.tar.gz ]; then
	wget https://github.com/openresty/lua-nginx-module/archive/$LUA_VER.tar.gz
fi
tar -zxvf $LUA_VER.tar.gz

# CD Back to the main dir
cd $NGINX_FOLDER

# Configure NGINX based on the build flags for the installed nginx
echo "#!/bin/bash" > build.sh
echo "./configure \\" >> build.sh
nginx -V 2>&1 | grep "configure arguments" | awk -F 'arguments:' '{print $2 " \\"}' >> build.sh
echo " --add-dynamic-module=$NGX_DEVEL \\" >> build.sh
echo " --add-dynamic-module=$LUA_MODULE" >> build.sh

sed -i 's/-fPIE/-fPIC/' build.sh

chmod +x build.sh
./build.sh

# you can change the parallism number 2 below to fit the number of spare CPU cores in your
# machine.
make -j2 modules
#make install

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
        exit 2
    fi

    cp $LUAJIT_LIB $OUTPUT_FOLDER/
    NGX=$?
    if [ $NGX -ne 0 ]; then
        echo "Failed to copy $LUAJIT_LIB, likely build failure"
        exit 3
    fi

    sed -i '/^pid/a load_module \/output\/ngx_http_lua_module.so;' /etc/nginx/nginx.conf
    sed -i '/^pid/a load_module \/output\/ndk_http_module.so;' /etc/nginx/nginx.conf
    nginx -t
    if [ $? -ne 0 ]; then
        echo "Module did not work with NGINX"
        exit 4
    fi

    cd $OUTPUT_FOLDER
    tar -czvf $OUTPUT_FOLDER/$BASE_VERSION-lua-module.tar.gz *.so
    echo "Tar file saved at $OUTPUT_FOLDER/nginx-$BASE_VERSION-lua-module.tar.gz"


else
    echo "Failed Build"
    exit 99
fi