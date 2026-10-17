# myapp — minimal Maven "Hello World" with CI/CD, Docker & Helm

A minimal Java "Hello World" project used as a learning and template repo. The application prints two lines and exits; the repository demonstrates how to build it with Maven, package it into a runnable JAR and a non-root Docker image, publish it through a GitHub Actions pipeline, and deploy it to Kubernetes with a Helm chart.

## Purpose

Show, end to end and with as little code as possible, how a tiny Java program moves from source to a running container and a Kubernetes workload:

`App.java` → `mvn package` (JAR) → `Dockerfile` (image) → GitHub Actions (push to Docker Hub) → Helm chart (Kubernetes `Job`)

## What it is

| Aspect | Detail |
|---|---|
| Language / runtime | Java 21 |
| Build tool | Apache Maven (single module, artifact `myapp`) |
| Test framework | JUnit 4.11 |
| Main class | `com.myapp.App` |
| Container image | `dbareldocker78/hello_world_db` (`eclipse-temurin:21-jre-alpine`, runs as non-root `appuser`) |
| Kubernetes | Helm chart `myapp` in `myapp/helm` — deploys a `batch/v1` **Job** because the app is one-shot |
| CI/CD | GitHub Actions — `.github/workflows/ci-cd.yml` |

## What it contains

| Path | Purpose |
|---|---|
| `myapp/pom.xml` | Maven build; sets `Main-Class: com.myapp.App` via `maven-jar-plugin` |
| `myapp/src/main/java/com/myapp/App.java` | The application (prints two lines and exits) |
| `myapp/src/test/java/com/myapp/AppTest.java` | JUnit 4 unit test |
| `myapp/Dockerfile` | Builds the runtime image from the versioned JAR |
| `myapp/helm/Chart.yaml` | Chart metadata (`name: myapp`, `version: 0.1.0`) |
| `myapp/helm/values.yaml` | Chart defaults (image, resources, job controls) |
| `myapp/helm/templates/job.yaml` | The Kubernetes `Job` resource |
| `myapp/helm/.helmignore` | Files excluded from the packaged chart |
| `.github/workflows/ci-cd.yml` | Build, package, publish and verify pipeline |
| `scripts/version.sh`, `scripts/version.ps1` | Compute the release version |
| `scripts/helm-package.sh`, `scripts/helm-package.ps1` | Package the Helm chart into a versioned `.tgz` |
| `build.ps1` | Local builder for a versioned, runnable JAR under `outputs/` |
| `.gitignore` | Ignored build output and scratch files |
| `.gitattributes` | Pins line endings so shell scripts stay LF |

## Project layout

```text
maven-hello-world_db/
├── .github/
│   └── workflows/
│       └── ci-cd.yml
├── myapp/
│   ├── helm/
│   │   ├── .helmignore
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── job.yaml
│   ├── src/
│   │   ├── main/java/com/myapp/App.java
│   │   └── test/java/com/myapp/AppTest.java
│   ├── Dockerfile
│   └── pom.xml
├── scripts/
│   ├── version.sh
│   ├── version.ps1
│   ├── helm-package.sh
│   └── helm-package.ps1
├── .gitattributes
├── .gitignore
├── build.ps1
└── readme.md
```

Build-time output (gitignored): `myapp/target/` from Maven, and `outputs/<version>/` from `build.ps1`.

## Quick start

```bash
# Build and run with Maven
mvn -f myapp/pom.xml clean package
java -jar myapp/target/myapp-1.0-SNAPSHOT.jar

# Docker
docker build --build-arg JAR_FILE=target/myapp-1.0-SNAPSHOT.jar \
  -t dbareldocker78/hello_world_db:latest -f myapp/Dockerfile myapp
docker run --rm dbareldocker78/hello_world_db:latest

# Package the Helm chart (-> outputs/helm/myapp-0.1.0.tgz)
./scripts/helm-package.sh

# Kubernetes (creates a Job named "myapp")
helm install myapp myapp/helm
```

Windows (PowerShell):

```powershell
# Build a versioned JAR with the helper script
./build.ps1 -Version v1
java -jar outputs/v1/myapp-v1.jar

# Package the Helm chart (-> outputs/helm/myapp-0.1.0.tgz)
./scripts/helm-package.ps1
```

## Outputs it generates

| Output | Produced by | Location / name |
|---|---|---|
| Compiled classes, test reports | `mvn package` | `myapp/target/`, `myapp/target/surefire-reports/` |
| Runnable JAR | `mvn package` | `myapp/target/myapp-1.0-SNAPSHOT.jar` |
| Versioned JAR + manifest | `build.ps1` | `outputs/<version>/myapp-<version>.jar` and `META-INF/MANIFEST.MF` |
| Docker image | CI, or local `docker build` | `dbareldocker78/hello_world_db:<version>` and `:latest` |
| Packaged Helm chart | `scripts/helm-package.*`, or the CI `package-chart` job | `outputs/helm/myapp-<chartVersion>.tgz` |
| Pipeline artifacts | GitHub Actions | uploaded `myapp-<version>.jar` and `helm-chart-myapp-<chartVersion>` |
| Kubernetes `Job` | `helm install myapp myapp/helm` | `Job`/pod named `myapp` (runs once, then TTL-cleaned) |

The release version takes the form `1.0.<buildId>` — `Major.Minor` comes from `myapp/pom.xml` and `buildId` is the CI run number (or a value you pass locally).

### Expected program output

```
Hello World!
My Name is Daniel Barel
```

