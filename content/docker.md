# Docker

Docker packages an application and everything it needs (runtime, libraries, config) into an **image** that runs the same way on your laptop, in CI, and in production. Kubernetes, ECS, and most CI systems run containers, so this is the foundation for everything that follows.

## Core concepts

| Term | Meaning |
|---|---|
| **Image** | A read-only template: filesystem layers plus metadata. Built from a `Dockerfile`. |
| **Container** | A running instance of an image, an isolated process on the host. |
| **Dockerfile** | Recipe of instructions to build an image. |
| **Registry** | Stores images: Docker Hub, AWS ECR, GitHub Container Registry. |
| **Tag** | Version label, for example `nginx:1.27` or `myapp:v1.2.0`. |
| **Volume** | Persistent storage that outlives a container. |

### Containers vs virtual machines

A VM virtualizes **hardware** and boots a full OS kernel, which takes minutes and gigabytes. A container shares the host **kernel** and isolates only the process (using Linux namespaces and cgroups), so it starts in milliseconds and is usually tens of megabytes.

> **Why:** "It works on my machine" goes away. The image *is* the machine.

## Install and verify

If you completed **Workstation Setup**, Docker is already installed. Verify it:

```bash
docker version        # client AND server sections should both appear
docker info | head -20
docker run hello-world
```

If the server section is missing, the daemon is not running. Start Docker Desktop, or run `sudo systemctl start docker` on Linux.

## Your first containers

```bash
docker run -d --name web -p 8080:80 nginx:1.27
# -d detached, --name a friendly name, -p hostPort:containerPort
curl localhost:8080

docker ps                    # running containers
docker ps -a                 # including stopped
docker logs -f web           # follow logs
docker exec -it web bash     # shell inside the running container
docker stop web && docker start web
docker rm -f web             # stop + remove
```

Try an interactive throwaway container:

```bash
docker run -it --rm ubuntu:24.04 bash   # --rm deletes it on exit
cat /etc/os-release
exit
```

Pass configuration with environment variables:

```bash
docker run -d --name db -e POSTGRES_PASSWORD=secret -p 5432:5432 postgres:16
docker logs db | tail -5
```

## Working with images

```bash
docker pull python:3.12-slim
docker images                       # list local images
docker image inspect python:3.12-slim | jq '.[0].Config.Env'
docker history python:3.12-slim     # see the layers
docker tag python:3.12-slim mypython:dev
docker rmi mypython:dev
docker system df                    # disk used by Docker
docker system prune                 # remove stopped containers, dangling images
```

Every instruction in a Dockerfile creates a **layer**. Layers are cached and shared between images, which is why the instruction order in a Dockerfile matters for build speed.

## Write a Dockerfile

Create a tiny Python web app:

```bash
mkdir -p ~/code/hello-docker && cd ~/code/hello-docker
```

`app.py`:

```python
from flask import Flask
import os, socket

app = Flask(__name__)

@app.get("/")
def index():
    return {"message": "Hello from Docker!", "host": socket.gethostname(),
            "version": os.getenv("APP_VERSION", "dev")}

@app.get("/health")
def health():
    return {"status": "ok"}
```

`requirements.txt`:

```text
flask==3.0.3
gunicorn==23.0.0
```

`Dockerfile`:

```dockerfile
# 1. Base image: small, pinned version
FROM python:3.12-slim

# 2. Working directory inside the image
WORKDIR /app

# 3. Copy dependency list first so this layer is cached
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy the source code (changes often, so it goes last)
COPY app.py .

# 5. Don't run as root
RUN useradd --create-home appuser
USER appuser

ENV APP_VERSION=1.0.0
EXPOSE 8000

# 6. Start command
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
```

`.dockerignore` keeps junk out of the build context:

```text
.git
__pycache__
*.pyc
.env
```

Build and run:

```bash
docker build -t hello-docker:1.0.0 .
docker run -d --name hello -p 8000:8000 hello-docker:1.0.0
curl localhost:8000
curl localhost:8000/health
```

### Key instructions

| Instruction | Purpose |
|---|---|
| `FROM` | Base image |
| `WORKDIR` | Set the working directory |
| `COPY` / `ADD` | Copy files in (prefer `COPY`) |
| `RUN` | Execute at **build** time |
| `ENV` | Environment variable |
| `EXPOSE` | Document the port (doesn't publish it) |
| `USER` | Run as non-root |
| `CMD` | Default command at **run** time (overridable) |
| `ENTRYPOINT` | Fixed executable. `CMD` becomes its arguments |

## Multi-stage builds

Compiled languages need build tools that should not ship to production. Multi-stage builds compile in one stage and copy only the result into a minimal final image. Example for Go:

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server .

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/server /server
USER nonroot
ENTRYPOINT ["/server"]
```

The final image is a few MB, with no shell and no package manager, so there is much less to attack.

## Volumes and bind mounts

Containers are disposable. Anything written inside one disappears when it is removed, unless you mount storage.

```bash
# Named volume, managed by Docker. Use it for databases.
docker volume create pgdata
docker run -d --name db -e POSTGRES_PASSWORD=secret -v pgdata:/var/lib/postgresql/data postgres:16
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=secret -v pgdata:/var/lib/postgresql/data postgres:16
# data survived

# Bind mount: a host folder, great for local development
docker run -d -p 8081:80 -v "$(pwd)/site:/usr/share/nginx/html:ro" nginx:1.27

docker volume ls
docker volume inspect pgdata
```

## Networking

```bash
docker network create appnet
docker run -d --name db  --network appnet -e POSTGRES_PASSWORD=secret postgres:16
docker run -it --rm --network appnet postgres:16 psql -h db -U postgres
# containers on the same user-defined network resolve each other by NAME
docker network ls
docker network inspect appnet
```

| Driver | Use |
|---|---|
| `bridge` (default) | Containers on one host |
| `host` | Share the host network stack (Linux only) |
| `none` | No networking |

## Docker Compose

Compose describes a multi-container application in one YAML file. Add `compose.yaml` to `hello-docker`:

```yaml
services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      APP_VERSION: "1.1.0"
      DATABASE_URL: postgres://postgres:secret@db:5432/postgres
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
docker compose up -d --build   # build and start everything
docker compose ps
docker compose logs -f web
docker compose exec db psql -U postgres
docker compose down            # stop and remove (add -v to delete volumes)
```

## Push to a registry

### Docker Hub

```bash
docker login
docker tag hello-docker:1.0.0 <your-dockerhub-user>/hello-docker:1.0.0
docker push <your-dockerhub-user>/hello-docker:1.0.0
```

### AWS ECR (used again in the AWS guide and the Capstone)

```bash
AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO=hello-docker

aws ecr create-repository --repository-name $REPO --region $AWS_REGION
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker tag hello-docker:1.0.0 $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:1.0.0
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:1.0.0
```

> **Tip:** Tag images with something traceable, such as a version (`1.4.2`) or Git SHA (`git rev-parse --short HEAD`). Avoid deploying `latest`: you can't tell what is running or roll back reliably.

## Best practices and security

- **Pin base images** (`python:3.12-slim`, not `python`), and prefer `slim`, `alpine` or `distroless`.
- **Order layers** from least to most frequently changed. Dependencies go before source code.
- **Run as non-root** with `USER`.
- **Never bake secrets** into images. They stay in the layer history forever. Pass them at runtime.
- Use **`.dockerignore`**.
- **One process per container.** Let the orchestrator handle the rest.
- **Scan images:** `docker scout cves hello-docker:1.0.0` or `trivy image hello-docker:1.0.0`.
- Add a **HEALTHCHECK**, or rely on Kubernetes probes later.

## Troubleshooting

| Symptom | Check |
|---|---|
| Container exits immediately | `docker logs <name>`. The main process ended or crashed. |
| `port is already allocated` | Another container or process uses that host port: `docker ps`, `ss -tulpn` |
| Can't reach app on `-p` port | App must listen on `0.0.0.0`, not `127.0.0.1`, inside the container |
| `permission denied ... docker.sock` | Add yourself to the `docker` group, then re-login |
| Out of disk | `docker system df`, then `docker system prune -a` (careful) |
| Need to look inside | `docker exec -it <name> sh`, `docker inspect <name>` |

## Lab: containerize and compose

1. Write a Dockerfile for any small app (Node, Python, Go, or a static site on nginx).
2. Make it run as non-root and keep the image under 200 MB. Check with `docker images`.
3. Add a `compose.yaml` with your app plus Redis or Postgres. The app must reach the database by service name.
4. Persist the database in a named volume. Prove the data survives `docker compose down` and `up`.
5. Push your image to Docker Hub or ECR with a version tag.
6. Scan it with `docker scout` or `trivy` and fix one finding, for example by switching to a slimmer base.

### Cheat sheet

| Task | Command |
|---|---|
| Run detached with port | `docker run -d -p 8080:80 --name x img` |
| Shell into container | `docker exec -it x sh` |
| Logs | `docker logs -f x` |
| Build | `docker build -t name:tag .` |
| Compose up / down | `docker compose up -d` / `docker compose down` |
| Clean up | `docker system prune` |
