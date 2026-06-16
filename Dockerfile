# ==========================================
# 第一阶段：编译动态模块 (Builder)
# ==========================================
FROM nginx:mainline AS builder

# 修复：额外安装了 libbrotli-dev，解决 ngx_brotli 编译时缺失动态链接库的问题
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    libpcre2-dev \
    zlib1g-dev \
    libssl-dev \
    libmaxminddb-dev \
    libbrotli-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 下载第三方模块源码
WORKDIR /opt
RUN git clone --recursive https://github.com/google/ngx_brotli.git && \
    git clone --recursive https://github.com/openresty/headers-more-nginx-module.git && \
    git clone --recursive https://github.com/leev/ngx_http_geoip2_module.git && \
    git clone --recursive https://github.com/nginx-modules/ngx_cache_purge.git

# 下载当前 Nginx 镜像完全对应版本的官方源码并解压
RUN NGINX_VER=$(nginx -v 2>&1 | cut -d'/' -f2 | cut -d' ' -f1) && \
    wget http://nginx.org/download/nginx-${NGINX_VER}.tar.gz && \
    tar -zxf nginx-${NGINX_VER}.tar.gz

# 进入官方源码目录，使用 --with-compat 模式编译 4 个动态模块
RUN cd /opt/nginx-$(nginx -v 2>&1 | cut -d'/' -f2 | cut -d' ' -f1) && \
    ./configure --with-compat \
                --add-dynamic-module=/opt/ngx_brotli \
                --add-dynamic-module=/opt/headers-more-nginx-module \
                --add-dynamic-module=/opt/ngx_http_geoip2_module \
                --add-dynamic-module=/opt/ngx_cache_purge && \
    make modules

# ==========================================
# 第二阶段：构建最终轻量级运行镜像 (Runtime)
# ==========================================
FROM nginx:mainline

# 安装 geoip2 和 brotli 运行所需的系统基础库
RUN apt-get update && apt-get install -y libmaxminddb0 libbrotli1 && rm -rf /var/lib/apt/lists/*

# 直接从第一阶段精准生成的 objs/ 目录下把所有 .so 复制过来
COPY --from=builder /opt/nginx-*/objs/*.so /usr/lib/nginx/modules/
