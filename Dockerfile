# Base image: nginx:lastest
FROM nginx:latest

# Install required packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    nodejs \
    npm \
    curl \
    cargo \
    && rm -rf /var/lib/apt/lists/*


# Install the node stack
COPY ./nodejs/file_provider/index.js /app/file_provider/index.js
COPY ./nodejs/file_provider/package.json /app/file_provider/package.json
COPY ./nodejs/file_provider/package-lock.json /app/file_provider/package-lock.json
WORKDIR /app/file_provider
RUN npm install

# Install the python stack
RUN mkdir -p /app/python/src
RUN mkdir -p /app/python/bin
COPY ./python/src/youtube.py /app/python/src/youtube.py
COPY ./python/requirements.txt /app/python/requirements.txt
WORKDIR /app/python
RUN python3 -m venv .venv
RUN bash -c "source .venv/bin/activate; pip3 install -r requirements.txt"

# Install the rust stack
RUN mkdir -p /app/rust/src
COPY ./rust/Cargo.toml /app/rust/Cargo.toml
COPY ./rust/src/main.rs /app/rust/src/main.rs

# Build the rust stack
WORKDIR /app/rust
RUN cargo build --release
RUN cp target/release/dfpwm_encoder /app/python/bin/dfpwm_encoder

# Remove the rust stack
WORKDIR /app
RUN rm -rf /app/rust

# Copy the nginx configuration
COPY ./docker/nginx.conf /etc/nginx/nginx.conf

# Copy the entrypoint script
COPY ./docker/app.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose the port
EXPOSE 80

# Run the entrypoint script on container startup also start nginx
ENTRYPOINT ["/app/entrypoint.sh"]


