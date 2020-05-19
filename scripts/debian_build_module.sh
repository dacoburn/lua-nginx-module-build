#!/bin/sh

#Global Variables
BASE_VERSION=`nginx -V 2>&1 | grep "nginx version" | awk -F "/" '{print $2}' | awk -F " " '{print $1}'`
VERSION=`dpkg -s nginx | grep Version | awk '{print $2}'`
CONFIG_FLAGS=`nginx -V 2>&1 | grep "configure arguments" | awk -F 'arguments:' '{print $2}'`
OSINFO=`cat /etc/os-release  | grep -e "^NAME=" | awk -F "\"" '{print $2}'`

# Number of CPUs to use at Compile time
CPUS=2

# Set this to 1 to use the sudo command. I recommend if you're doing this to
# have sudo not prompt for a password...
SUDO=1

# Set this to 1 to only build the dynamix modules, other wise builds 
# NGINX binary also
ONLY_MODULES=0

# if Sudo is turned on set the prefix of sudo
if [ $SUDO -eq 1 ]; then
    prefix=sudo
fi

NGINX_FOLDER=$BASE_FOLDER/nginx-$BASE_VERSION
# Extra and Objects folder
EXTRA_FOLDER=$NGINX_FOLDER/extra
OBJS_FOLDER=$NGINX_FOLDER/objs

# LUA Framework URL & Version
lua_framework_version=0.10.15
lua_framework_url=https://github.com/openresty/lua-nginx-module/archive/v$lua_framework_version.tar.gz

# LUA Jit URL & Version
luajit_release=2.1-20200102
luajit_full_name=luajit2-$luajit_release
luajit_source_url=https://codeload.github.com/openresty/luajit2/tar.gz/v$luajit_release

# ngx devel URL & Version
ngx_devel_release=0.3.1
ngx_devel_full_name=ngx_devel_kit-$ngx_devel_release
ngx_devel_url=https://codeload.github.com/vision5/ngx_devel_kit/tar.gz/v$ngx_devel_release

# Build info for supporting modules

# LUA Jit Locations
export LUAJIT_INC=/usr/local/include/luajit-2.1
export LUAJIT_LIB=/usr/lib64
# ngx devel Locations
ngx_devel_location=$EXTRA_FOLDER/$ngx_devel_full_name
lua_module_location=$EXTRA_FOLDER/lua-nginx-module-$lua_framework_version


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

# Download LUA Jit
if [ ! -d $EXTRA_FOLDER ]; then
    echo "Making Extra Folder: $EXTRA_FOLDER"
    mkdir $EXTRA_FOLDER
fi

# Switch to the Extras folder for the modules
cd $EXTRA_FOLDER

# Download the LUA JiT source
if [ ! -f $luajit_full_name.tar.gz ]; then
    wget $luajit_source_url z -O $EXTRA_FOLDER/$luajit_full_name.tar.gz
fi

# Extract and Build LUA JiT
tar -zxvf $luajit_full_name.tar.gz
cd $EXTRA_FOLDER/$luajit_full_name

make -j$CPUS
# Currently installing it since the LUA Framework build uses it. Might need to 
# copy the libluajit libraries to the system where you are installing NGINX
make install
ln -s /usr/local/lib/libluajit-5.1.so.2 /usr/lib


cd $EXTRA_FOLDER

# Get and extract nginx devel kit, we don't build this as it is built as part of
# the nginx build process
if [ ! -f v$ngx_devel_release.tar.gz ]; then
    wget $ngx_devel_url -O $EXTRA_FOLDER/v$ngx_devel_release.tar.gz
fi
tar -zxvf v$ngx_devel_release.tar.gz

# Get and extract the lua framework source same as the previous one, it is made
# by the nginx build.

if [ ! -f v$lua_framework_version.tar.gz ]; then
    wget $lua_framework_url -O $EXTRA_FOLDER/v$lua_framework_version.tar.gz
fi
tar -zxvf v$lua_framework_version.tar.gz

# CD Back to the main dir
cd $NGINX_FOLDER

# Configure NGINX based on the build flags for the installed nginx or the
# manually provided flags
echo "#!/bin/bash" > build.sh
echo "./configure \\" >> build.sh
echo "$CONFIG_FLAGS \\" >> build.sh
echo " --add-dynamic-module=$ngx_devel_location \\" >> build.sh
echo " --add-dynamic-module=$lua_module_location" >> build.sh

sed -i 's/-fPIE/-fPIC/' build.sh

chmod +x build.sh
./build.sh

# If you specified only modules then only the dynamic modules will be built.
# Otherwise the modules and the nginx binary will be compiled. If you are 
# making the nginx binary I have it set up to install it.
if [ $ONLY_MODULES -eq 1 ]; then
    make -j$CPUS modules
else
    make -j$CPUS
    make install
fi

# This section is tests to ensure the build completed successfully. If the 
# return code of the previous build is NOT 0 then something went wrong.
RET=$?
if [ $RET -eq 0 ]; then
    # Make the $OUTPUT_FOLDER to copy the dynamic modules to and make the final
    # tar file for distribution.
    lib_folder=$OUTPUT_FOLDER
    modules_folder=$lib_folder
    mkdir -p $modules_folder
    echo "Successful Build"
    
    # Copy and verify that the copy of ndk_http_module.so to the output folder
    # worked
    cp $OBJS_FOLDER/ndk_http_module.so $modules_folder/ndk_http_module.so
    NDK=$?
    if [ $NDK -ne 0 ]; then
        echo "Failed to copy ndk_http_module.so, likely build failure"
        exit 1
    fi
    
    # Copy and verify that the copy of ngx_http_lua_module.so to the output folder
    # worked
    cp $OBJS_FOLDER/ngx_http_lua_module.so $modules_folder/ngx_http_lua_module.so
    NGX=$?
    if [ $NGX -ne 0 ]; then
        echo "Failed to copy ngx_http_lua_module.so, likely build failure"
        exit 1
    fi

    # I seem to include the lib lua jit on centos7. I'm adding it to the output
    # folder
    cp /usr/local/lib/libluajit* $lib_folder/


    # Check to see if NGINX is installed in the path now. If for some reason it 
    # is not, then no point in running the checks to see if the modules work 
    # with the nginx binary.
    nginx_check_command=`which nginx`
    NGINX_CHECK=$?
    if [ $NGINX_CHECK -eq 0 ]; then
        # Check to see if the lua module has already been added to the nginx.conf
        grep -q "ngx_http_lua_module.so;" /etc/nginx/nginx.conf
        grep_result=$?
        if [ $grep_result -ne 0 ]; then
            sed -i '/pid;/a load_module '"$modules_folder"'/ngx_http_lua_module.so;' /etc/nginx/nginx.conf
        fi
        # Check to see if the ndk module has already been added to the nginx.conf
        grep -q "ndk_http_module.so;" /etc/nginx/nginx.conf
        grep_result=$?
        if [ $grep_result -ne 0 ]; then
            sed -i '/pid;/a load_module '"$modules_folder"'/ndk_http_module.so;' /etc/nginx/nginx.conf
        fi
        # Check to see if the nobody user is already enabled
        grep -q "#user  nobody;" /etc/nginx/nginx.conf
        grep_result=$?
        if [ $grep_result -eq 0 ]; then
            sed -i 's/#user  nobody;/user  nobody;/g' /etc/nginx/nginx.conf
        fi

        # Adding as this is needed for the latest versions of lua from Openresty
        sed -i '/http.*{/a lua_load_resty_core off;' /etc/nginx/nginx.conf

        # Now that the nginx.conf is set to load the freshly built modules we
        # check to see if they are binary compaitable with the nginx binary.
        # If they are then everything was good.
        nginx -t
        if [ $? -ne 0 ]; then
            # Either the modules don't exist or they were not compaitable with 
            # nginx for some reason.
            echo "Module did not work with NGINX"
            exit 1
        fi
    else
        echo "nginx wasn't installed, skipping nginx test"
    fi

    # Creating the tar file with the freshly built dynamic module files
    # Resulting tar file should be able to be extracted from the / and have 
    # everything in the correct location. I might consider making an RPM install
    # from this.
    cd $OUTPUT_FOLDER
    TAR_NAME=nginx-$BASE_VERSION
    tar -czvf $OUTPUT_FOLDER/$TAR_NAME-lua-module.tar.gz ./*
    echo "Tar file saved at $OUTPUT_FOLDER/$TAR_NAME-lua-module.tar.gz"


else
    echo "Failed Build"
    exit 1
fi