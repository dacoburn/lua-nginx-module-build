# lua-nginx-module-build

## Description

This Docker example enables you to with a couple easy commands make the dynamic modules for the LUA Framework for NGINX. This specific docerfile is for Amazon Linux 2. It can be used with any version of Amazon Linux 2 by changing the `FROM` tag to use a particular version instead of latest.

## Usage

**Building the Container**

The build option will build the Docker container. This will have the base configuration in order to run the build script.
`make build docker_user=USERNAME`

**Running the Container**

`make run-once docker_user=USERNAME`

I recommend creating the `output` folder before running Docker. If you don't it should make it on its own if it doesn't exist. After the execution runs you should have three files:

    - ndk_http_module.so
    - ngx_http_lua_module.so
    - nginx-[NGINX_VERSION]-lua-module.tar.gz

Once you have the files you can copy them over to your NGINX Server and load them by doing the following directives in your `nginx.conf` before the `http` context:

````
load_module modules/ndk_http_module.so;
load_module modules/ngx_http_lua_module.so;
````
