#!/bin/bash

# Get NGINX Source

# Global Variables

# Number of CPUs to use at Compile time
CPUS=2
# Set this to 1 to only build the dynamix modules, other wise builds 
# NGINX binary also
ONLY_MODULES=1

OSID=`cat /etc/os-release | grep -e "^ID=" | awk -F "=" '{print $2}' | sed 's/\"//g'`

# Get the installed NGINX Version
nginx_check_command=`which nginx`
NGINX_CHECK=$?

if [ $NGINX_CHECK -eq 1 ]; then
    # Since the nginx binary was not found in the path we need hard coded values
    echo "Using Hard Coded NGINX Version, NGINX not found"
    NGINX_VERSION=1.17.10
    CONFIG_FLAGS='--user=nginx --group=nginx --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --with-http_gzip_static_module --with-http_stub_status_module --with-http_ssl_module --with-pcre --with-file-aio --without-http_scgi_module --without-http_uwsgi_module --without-http_fastcgi_module --with-cc-opt=-O2 --with-ld-opt=-Wl,-rpath,/usr/local/lib --add-module=/home/ec2-user/ngx_devel_kit-master'
else
    # nginx was found in the path, so getting the info dynamically
    NGINX_VERSION=`nginx -V 2>&1 | grep "nginx version" | awk -F "/" '{print $2}'`
    CONFIG_FLAGS=`nginx -V 2>&1 | grep "configure arguments" | awk -F 'arguments:' '{print $2 " \\ "}'`
fi

# Get the yum variant of the version
NGINX_VERSION_YUM=`rpm -qa nginx | awk 'BEGIN{FS=OFS="."}{NF--; print}'`
nginxver="nginx-$NGINX_VERSION"
NGINX_FOLDER=$BASE_FOLDER/$nginxver
source_url=http://nginx.org/packages/centos/$RHELVER/SRPMS
normal_url=http://nginx.org/packages/centos/$RHELVER/$basearch/RPMS/

# Building out variables needed
nginxver="nginx-$NGINX_VERSION"
NGINX_FOLDER=$BASE_FOLDER/$nginxver
# Extra and Objects folder
EXTRA_FOLDER=$NGINX_FOLDER/extra
OBJS_FOLDER=$NGINX_FOLDER/objs

# Source Info for the Packages
nginx_source_url=http://nginx.org/download/$nginxver.tar.gz

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

if [ "$OSID" == "amzn" ] || [ "$OSID" == "amzn" ]; then
    # Steps for Amazon Linux
    export source_rpm=$NGINX_VERSION_YUM.src.rpm
    if [ ! -f $source_rpm ]; then
        # Install the Source RPM
        yumdownloader --source nginx
        rpm -i $source_rpm
        if [ -f /root/rpmbuild/SOURCES/$nginxver.tar.gz ]; then
            cp /root/rpmbuild/SOURCES/$nginxver.tar.gz ./
        elif [ -f cp /usr/src/rpm/SOURCES/$nginxver.tar.gz ]; then
            cp /usr/src/rpm/SOURCES/$nginxver.tar.gz ./
        else
            echo "Something went wrong with the soruce download"
            exit 1
        fi
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
    else
        rpm -i $source_rpm
    fi

    if [ -f /root/rpmbuild/SOURCES/$nginxver.tar.gz ]; then
        cp /root/rpmbuild/SOURCES/$nginxver.tar.gz ./
    elif [ -f /usr/src/rpm/SOURCES/$nginxver.tar.gz ]; then
        cp /usr/src/rpm/SOURCES/$nginxver.tar.gz ./
    else
        echo "Something went wrong with the source download"
        exit 1
    fi
fi


if [ ! -d $nginxver ]; then
    tar -zxvf $nginxver.tar.gz
fi

# Download LUA Jit
if [ ! -d $EXTRA_FOLDER ]; then
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

# Change to the $NGINX_FOLDER to do the configure and build
cd $NGINX_FOLDER

# Configure NGINX based on the build flags for the installed nginx or the
# manually provided flags
echo "#!/bin/bash" > build.sh
echo "./configure \\" >> build.sh
echo "$CONFIG_FLAGS \\" >> build.sh
echo " --add-dynamic-module=$ngx_devel_location \\" >> build.sh
echo " --add-dynamic-module=$lua_module_location" >> build.sh

# I was having issues with the config flags when pulling dynamically. Also I 
# liked being able to look and see what the ./configure command was after things
# ran
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
    lib_folder=$OUTPUT_FOLDER/usr/lib
    modules_folder=$lib_folder/modules
    mkdir -p 
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
            sed -i '/pid;/a load_module \/output\/usr\/lib\/modules\/ngx_http_lua_module.so;' /etc/nginx/nginx.conf
        fi
        # Check to see if the ndk module has already been added to the nginx.conf
        grep -q "ndk_http_module.so;" /etc/nginx/nginx.conf
        grep_result=$?
        if [ $grep_result -ne 0 ]; then
            sed -i '/pid;/a load_module \/output\/usr\/lib\/modules\/ndk_http_module.so;' /etc/nginx/nginx.conf
        fi
        # Check to see if the nobody user is already enabled
        grep -q "#user  nobody;" /etc/nginx/nginx.conf
        grep_result=$?
        if [ $grep_result -eq 0 ]; then
            sed -i 's/#user  nobody;/user  nobody;/g' /etc/nginx/nginx.conf
        fi

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
    tar -czvf $OUTPUT_FOLDER/$nginxver-lua-module.tar.gz *.so
    echo "Tar file saved at $OUTPUT_FOLDER/$nginxver-lua-module.tar.gz"


else
    echo "Failed Build"
    exit 1
fi