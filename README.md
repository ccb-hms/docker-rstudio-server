# docker-rstudio-server
A repository for multi-arch (AMD64 / ARM64) RStudio Server containers accessible via ssh and https.

## Running the Image
The follwing can be used to pull and run the image from DockerHub, without needing to build locally:
```
docker \
    run \
    --rm \
    --name rstudio-server \
    -d \
    -v /tmp:/HostData \
    -p 2200:22 \
    -p 8787:8787 \
    -e CONTAINER_USER_USERNAME=test \
    -e CONTAINER_USER_PASSWORD=test \
    hmsccb/rstudio-server:4.2.0
```

## Building the Image
If you wish to build this image yourself, carefully review the instructions below and 
substitute place-holder arguments appropriately.

While it is possible to perform multi-arch builds on a single Docker instance 
using `buildx` and emulation, the process is at best slow
and and worst buggy, with some steps failing under emulation but completing correctly on native 
architecture.  We recommend using `buildx` to perform a multi-node build, where 
the ARM64 image is built on an ARM64 host, and the AMD64 image is built on an AMD64 host. 
The images are then bundled by `buildx` in a Docker manifest list.  When pushed to a registry and deployed,
the Docker client will automatically execute the image that matches its native architecture.

### Setting up Multi-Arch Distributed Build

Substitute REMOTE_USER@REMOTE_HOST appropriate to your environment.

```
# from an ARM64 host with AMD64 remote
# (reverse arm64 and amd64 platforms in the next two buildx commands if
# executing from AMD64 host with ARM64 remote)

# create the buildx node on the localhost
docker buildx create --name distributed_builder --node distributed_builder_arm64 --platform linux/arm64  --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10000000 --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=10000000

# this assumes password-less ssh authentication has been set up for 
# REMOTE_USER@REMOTE_HOST
# eg:

ssh-keygen -t rsa -b 4096 -C "YOUR_EMAIL"
ssh-copy-id REMOTE_USER@REMOTE_HOST

# create the remote buildx node
docker buildx create --name distributed_builder --append --node distributed_builder_amd64 --platform linux/amd64 ssh://REMOTE_USER@REMOTE_HOST --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10000000 --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=10000000

# tell buildx to use the new builder
docker buildx use distributed_builder

# initialize the buildx images
docker buildx inspect --bootstrap
```

### Building the Image

Substitute NEW_TAG as appropriate for your use case.

```
docker buildx build --platform linux/arm64,linux/amd64 --progress=plain --push --tag NEW_TAG -f 4.2.0.Dockerfile .
```

To load the image directly into Docker without pushing to a registry (select the appropriate platform specification
for your architecture):

```
docker buildx build --platform linux/arm64 --progress=plain --load --tag NEW_TAG -f 4.2.0.Dockerfile .
```

