#
# RStudio Server Container Image
# Author: Nathan Palmer
# Copyright: Harvard Medical School
#

FROM hmsccb/r-command-line:4.2.0

#------------------------------------------------------------------------------
# Install RStudio Server
#------------------------------------------------------------------------------

WORKDIR /tmp
RUN wget https://github.com/rstudio/rstudio/tarball/v2022.02.1+461
RUN tar zxvf v2022.02.1+461
RUN cd /tmp/rstudio-rstudio-8aaa5d4/dependencies/linux && ./install-dependencies-focal 
RUN cd /tmp/rstudio-rstudio-8aaa5d4 && mkdir build 
# figure out how many cores we should use for compile, and call cmake / make -j to do multithreaded build
RUN ["/bin/bash", "-c", "x=$(cat /proc/cpuinfo | grep processor | wc -l) && let ncores=$x-1 && if (( ncores < 1 )); then let ncores=1; fi && echo \"export N_BUILD_CORES=\"$ncores >> /tmp/ncores.txt"]
RUN ["/bin/bash", "-c", "source /tmp/ncores.txt && cd /tmp/rstudio-rstudio-8aaa5d4/build  && cmake -j $N_BUILD_CORES .. -DRSTUDIO_TARGET=Server -DCMAKE_BUILD_TYPE=Release"]
RUN ["/bin/bash", "-c", "source /tmp/ncores.txt && cd /tmp/rstudio-rstudio-8aaa5d4/build && make -j $N_BUILD_CORES install"]
RUN cp /usr/local/extras/init.d/debian/rstudio-server /etc/init.d/
RUN mkdir -p /etc/R
RUN mkdir -p /etc/rstudio
RUN useradd -r rstudio-server

# server configuration
RUN cat <<EOF >/etc/rstudio/rserver.conf
server-user=rstudio-server
server-daemonize=0
EOF

# Log to stderr
RUN cat <<EOF >/etc/rstudio/logging.conf
[*]
log-level=warn
logger-type=syslog
EOF

# https://github.com/rocker-org/rocker-versioned2/issues/137
RUN rm -f /var/lib/rstudio-server/secure-cookie-key

## use more robust file locking to avoid errors when using shared volumes:
RUN echo "lock-type=advisory" >/etc/rstudio/file-locks


#------------------------------------------------------------------------------
# Create s6 rstudio-server service
#------------------------------------------------------------------------------

RUN mkdir -p /etc/s6-overlay/s6-rc.d/rstudio-server
RUN echo 'longrun' >> /etc/s6-overlay/s6-rc.d/rstudio-server/type
RUN echo '#!/bin/bash\nexec 2>&1\n/usr/local/bin/rserver' >> /etc/s6-overlay/s6-rc.d/rstudio-server/run
RUN mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/rstudio-server
EXPOSE 8787


# tell R to use cairo for graphics so it works in RStudio Server front end
RUN echo 'options(bitmapType="cairo")' >> $R_HOME/etc/Rprofile.site
