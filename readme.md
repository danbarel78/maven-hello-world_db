# A simple, minimal Maven example: hello world

To create the files in this git repo we've already run `mvn archetype:generate` from http://maven.apache.org/guides/getting-started/maven-in-five-minutes.html
    
    mvn archetype:generate -DgroupId=com.myapp.app -DartifactId=myapp -DarchetypeArtifactId=maven-archetype-quickstart -DarchetypeVersion=1.4 -DinteractiveMode=false

Now, to print "Hello World!", type either...

    cd myapp
    mvn compile
    java -cp target/classes com.myapp.app.App

or...

    cd myapp
    mvn package
    java -cp target/myapp-1.0-SNAPSHOT.jar com.myapp.app.App

Running `mvn clean` will get us back to only the source Java and the `pom.xml`:

    murphy:myapp pdurbin$ mvn clean --quiet
    murphy:myapp pdurbin$ ack -a -f
    pom.xml
    src/main/java/com/myapp/app/App.java
    src/test/java/com/myapp/app/AppTest.java

Running `mvn compile` produces a class file:

    murphy:myapp pdurbin$ mvn compile --quiet
    murphy:myapp pdurbin$ ack -a -f
    pom.xml
    src/main/java/com/myapp/app/App.java
    src/test/java/com/myapp/app/AppTest.java
    target/classes/com/myapp/app/App.class
    murphy:myapp pdurbin$ 
    murphy:myapp pdurbin$ java -cp target/classes com.myapp.app.App
    Hello World!

Running `mvn package` does a compile and creates the target directory, including a jar:

    murphy:myapp pdurbin$ mvn clean --quiet
    murphy:myapp pdurbin$ mvn package > /dev/null
    murphy:myapp pdurbin$ ack -a -f
    pom.xml
    src/main/java/com/myapp/app/App.java
    src/test/java/com/myapp/app/AppTest.java
    target/classes/com/myapp/app/App.class
    target/maven-archiver/pom.properties
    target/myapp-1.0-SNAPSHOT.jar
    target/surefire-reports/com.myapp.app.AppTest.txt
    target/surefire-reports/TEST-com.myapp.app.AppTest.xml
    target/test-classes/com/myapp/app/AppTest.class
    murphy:myapp pdurbin$ 
    murphy:myapp pdurbin$ java -cp target/myapp-1.0-SNAPSHOT.jar com.myapp.app.App
    Hello World!

Running `mvn clean compile exec:java` requires https://www.mojohaus.org/exec-maven-plugin/

Running `java -jar target/myapp-1.0-SNAPSHOT.jar` requires http://maven.apache.org/plugins/maven-shade-plugin/

# Runnable Jar:
JAR Plugin
The Maven’s jar plugin will create jar file and we need to define the main class that will get executed when we run the jar file.
```
<plugin>
  <artifactId>maven-jar-plugin</artifactId>
  <version>3.0.2</version>
  <configuration>
    <archive>
      <manifest>
        <addClasspath>true</addClasspath>
        <mainClass>com.myapp.App</mainClass>
      </manifest>
    </archive>
  </configuration>
</plugin>
```


# Folder tree before package:
```
├── pom.xml
└── src
    ├── main
    │   └── java
    │       └── com
    │           └── myapp
    │               └── app
    │                   └── App.java
    └── test
        └── java
            └── com
                └── myapp
                    └── app
                        └── AppTest.java

```
# Folder tree after package:
```

.
├── pom.xml
├── src
│   ├── main
│   │   └── java
│   │       └── com
│   │           └── myapp
│   │               └── app
│   │                   └── App.java
│   └── test
│       └── java
│           └── com
│               └── myapp
│                   └── app
│                       └── AppTest.java
└── target
    ├── classes
    │   └── com
    │       └── myapp
    │           └── app
    │               └── App.class
    ├── generated-sources
    │   └── annotations
    ├── generated-test-sources
    │   └── test-annotations
    ├── maven-archiver
    │   └── pom.properties
    ├── maven-status
    │   └── maven-compiler-plugin
    │       ├── compile
    │       │   └── default-compile
    │       │       ├── createdFiles.lst
    │       │       └── inputFiles.lst
    │       └── testCompile
    │           └── default-testCompile
    │               ├── createdFiles.lst
    │               └── inputFiles.lst
    ├── myapp-1.0-SNAPSHOT.jar
    ├── surefire-reports
    │   ├── com.myapp.app.AppTest.txt
    │   └── TEST-com.myapp.app.AppTest.xml
    └── test-classes
        └── com
            └── myapp
                └── app
                    └── AppTest.class
```

# CI/CD Pipeline Manual Validation

This project contains a GitHub Actions CI/CD pipeline (`.github/workflows/ci-cd.yml`) and a `Dockerfile` under `myapp/`. The pipeline builds a versioned JAR, uploads it as an artifact, and builds/pushes a Docker image tagged with the version.

The version format is:

```
<Major>.<Minor>.<BuildId>
```

- `Major.Minor` is read from `myapp/pom.xml` (for example, `1.0-SNAPSHOT` becomes `1.0`).
- `BuildId` is the GitHub Actions run number when running in CI, or the value you pass locally (e.g. `1`).

### Incrementing Major or Minor

To increment the **Major** or **Minor** version, edit the `<version>` tag in `myapp/pom.xml`:

```xml
<version>1.1-SNAPSHOT</version>
```

Then commit and push the change. The next CI/CD run (and the next local validation) will produce versions like `1.1.1`, `1.1.2`, etc.

Examples:

| pom.xml `<version>` | CI BuildId | Resulting version |
|---|---|---|
| `1.0-SNAPSHOT` | `42` | `1.0.42` |
| `1.1-SNAPSHOT` | `10` | `1.1.10` |
| `2.0-SNAPSHOT` | `5` | `2.0.5` |

## Validate the CI/CD steps locally

> These commands are for **Linux/macOS**. On Windows, use the equivalent PowerShell commands or run the Bash scripts from Git Bash.

### 1. Compute the version

```bash
chmod +x scripts/version.sh
VERSION=$(scripts/version.sh 1)
echo "$VERSION"
```

Expected output:

```
1.0.1
```

On Windows:

```powershell
.\scripts\version.ps1 -BuildId 1
```

Expected output:

```
1.0.1
```

### 2. Build the Maven project

```bash
cd myapp
mvn clean package
```

Verify the JAR exists:

```bash
ls target/myapp-1.0-SNAPSHOT.jar
```

### 3. Package the versioned artifact

```bash
cp myapp/target/myapp-1.0-SNAPSHOT.jar myapp/target/myapp-${VERSION}.jar
ls myapp/target/myapp-${VERSION}.jar
```

### 4. Build the Docker image

The `Dockerfile` is inside `myapp/`, so the build context is `myapp` and the JAR path is relative to that context.

```bash
docker build \
  --build-arg JAR_FILE=target/myapp-${VERSION}.jar \
  -t dbareldocker78/hello_world_db:${VERSION} \
  -t dbareldocker78/hello_world_db:latest \
  -f myapp/Dockerfile \
  myapp
```

Verify the images were created:

```bash
docker images dbareldocker78/hello_world_db --format '{{.Tag}}'
```

Expected output:

```
1.0.1
latest
```

### 5. Run the Docker container locally

```bash
docker run --rm dbareldocker78/hello_world_db:${VERSION}
```

Expected output:

```
Hello World!
My Name is Daniel Barel
```

### 6. Verify the container does NOT run as root

```bash
docker run --rm --entrypoint /bin/sh dbareldocker78/hello_world_db:${VERSION} -c id
```

Expected output:

```
uid=100(appuser) gid=101(appgroup) groups=101(appgroup)
```

### 7. Clean up local artifacts (optional)

```bash
rm myapp/target/myapp-${VERSION}.jar
docker rmi dbareldocker78/hello_world_db:${VERSION} dbareldocker78/hello_world_db:latest
```

## GitHub Actions Workflow

The workflow runs on every push or pull request to `main`/`master`, plus manual `workflow_dispatch` triggers.

Before pushing triggers a Docker Hub push, add these repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

The workflow will:
1. Compute `Major.Minor.<GITHUB_RUN_NUMBER>`.
2. Run `mvn -f myapp/pom.xml clean package`.
3. Package and upload `myapp/target/myapp-<version>.jar` as a workflow artifact.
4. Build the Docker image from the `myapp` context, tag it with the version, and push it to Docker Hub.

Docker push is skipped on pull requests, to avoid exposing secrets to forked repositories.
