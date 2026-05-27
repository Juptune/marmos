FROM debian:bookworm

RUN apt update && apt install -y curl jq xz-utils libxml2 build-essential
RUN curl -fsS https://dlang.org/install.sh | bash -s dub-1.22.0
RUN curl -fsS https://dlang.org/install.sh | bash -s ldc-1.40.1

WORKDIR /app
COPY . .
RUN cd clean && bash -c "source ~/dlang/dub-1.22.0/activate && source ~/dlang/ldc-1.40.1/activate && ./dustmite.bash"