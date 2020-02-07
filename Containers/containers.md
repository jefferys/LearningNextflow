# Running nextflow processes with containers

There are three ways to use containers with nextflow:

1. Run nextflow itself in a container
2. Have one container for the entire workflow
3. Have one container per process.

## Running nextflow in a container
Not going to talk about running nextflow in a container as it is not clear that is easy or secure. Would be my preference, but to use containers easily would require nextflow to run in some kind of net-sever mode. I would prefer that, but that's not how it works. Given that, have to mount the docker socket for non-root use, which is a security issue.

## Running the entire workflow out of a specific container

This is a "fat-image" approach, where the container is essentially used as a virtual machine.

* Must have Docker installed where running - How does this interact with a cluster? Where does Docker need to be installed?
*

### Docker container

The HelloWorld script should run in an docker with bash, so lets try the Debian release.

Need to be on a node with docker, so log in to one

```
srun -c 2 --mem-per-cpu 2G --partition dockerbuild --pty bash -i
```

It does have nextflow, as can be seen via `nextflow help run`

To get a docker container used for running the entire process, can specify this on the command line, in the config file, [where else?]

#### Dockerized from the command line

```
$ mkdir -p Containers/DockerFat
$ cp HelloWorld/helloWait.nf Containers/helloDocker.nf
$ cd Containers/DockerFat
$ vi helloDocker.nf
# Change the greeting string from "Hello world!" to "Hello Docker"

$ nextflow run ../helloDocker.nf -with-docker debian:latest

N E X T F L O W  ~  version 19.10.0
Launching `../helloDocker.nf` [friendly_murdock] - revision: 93932ef807
executor >  local (1)
[55/716535] process > splitLetters   [100%] 1 of 1, failed: 1 ✘
[-        ] process > convertToUpper -
Error executing process > 'splitLetters'

Caused by:
  Process `splitLetters` terminated with an error exit status (1)

Command executed:

  sleep 5
  printf 'Hello Stuart' | split -b 6 - chunk_
  sleep 5

Command exit status:
  1

Command output:
  (empty)

Command error:
  split: chunk_aa: Permission denied

Work dir:
  /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892

Tip: view the complete command output by changing to the process work dir and entering the command `cat .command.out`
```

That doesn't work due to file permissions. Lets see what the actual command was:

```
less work/55/716535daa8affe02dcd898d274e892/.command.run
...
nxf_launch() {
    docker run -i -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash --name $NXF_BOXID debian:latest -c "/bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892/.command.sh"
}
```

Lets try this directly from the command line. Interesting that this does not include "--rm", so the container should hang around, but it does not. It is explicitly cleaned up with a `docker kill $NXF_BOXID` in `on_term()` and then a `docker rm $NXF_BOXID &>/dev/null || true` in `on_exit()`

The only variable here is $NXF_BOXID, which is set in nxf_main() including a random value:

```
NXF_BOXID="nxf-$(dd bs=18 count=1 if=/dev/urandom 2>/dev/null | base64 | tr +/ 0A)"
echo $NXF_BOXID
nxf-vi7VPISznxCb5ZgPMThIAOl4
```

so I will just use that explicitly, and add a --rm to clean up.

```
$ docker run -i --rm -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash --name nxf-vi7VPISznxCb5ZgPMThIAOl4 debian:latest -c "/bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892/.command.sh"

split: chunk_aa: Permission denied
```

Same error. OK, lets try again but leave the container open as a terminal (make it -it) at a bash shell (end with the shell) and try manually. Note that the (bash reference manual)[https://www.gnu.org/software/bash/manual/html_node/Invoking-Bash.html] states that all `set` options can be used as bash options at invocation

```
$ docker run -it --rm -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash --name nxf-vi7VPISznxCb5ZgPMThIAOl4 debian:latest -c "/bin/bash -ue"

bash: SUDO_USER: unbound variable

# Inside container
$ pwd
/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat
$ touch "someFile"
touch: cannot touch 'someFile': Permission denied
```

OK. Don't have permission to write to anything as "root". Have to try to set user and group on entry into container to be me. Lets see what settings I can configure in the `docker.` config context, as referenced (here)[https://www.nextflow.io/docs/latest/config.html#scope-docker].

OK, important ones seem to be:

* **`enabled`**` = true` - Turn on docker processing of process steps
* **`temp`**` = <PATH>` - Use the specified temp directory. `auto` is a special value that means create a new temp directory for each docker container. Not sure what the default is.
* **`engineOptions`**` = "<TEXT>"` - Specify any additional options to the `docker` command.
* **`runOptions`**` = "<TEXT>"` - Specify any additional options to the `docker run` command.
* **`registry`**` = <local registry>` - path to private local docker registry, without protocol prefix (e.g. no http://).
* **`fixOwnership`**` = true` - Set the file ownership of files created by the docker container. [TODO: Not sure what this means.]
* **`mountFlags`**` = "<FL,AGS>"` - Add the specified flags to the volume mounts e.g. `mountFlags = 'ro,Z'`

So need to set user information via the `runOptions` option. Lets try it directly and see what happens. The `-u` docker flag lets this be set need to be set to me, so let try `-u "$(id -u)":"$(id -g)"`

```
$ docker run -u "$(id -u)":"$(id -g)" -it --rm -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/55/716535daa8affe02dcd898d274e892 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash --name nxf-vi7VPISznxCb5ZgPMThIAOl4 debian:latest -c "/bin/bash -ue"

bash: SUDO_USER: unbound variable

# Inside container
$ touch "someFile"
$ exit

# outside container
$ ls
someFile  work/
```

That worked! So lets try it as a command line addition. Note need to either escape the "$" or amke the whole thing a non-editiable string so that the "$(...)" show up as text instead of being replace on the command line when running this.

```
$nextflow run ../helloDocker.nf -with-docker -docker.runOptions '$(id -u):$(id -g)' debian:latest

Unknown option: -docker.runOptions -- Check the available commands and options and syntax with 'help'
```

Why can't any options be used at the command line? That's the first major failing so far. Looks like only process.* context values are allowed. So lets move on to the config file.


#### Dockerized from the config file

Continuing what we were trying above, lets edit the user config file so the default for running docker includes the run options as specified. That means creating the file ` ~/.nextflow/config` or adding to it:

```
// Let docker containers read and write like me by default
docker.runOptions = '-u $(id -u):$(id -g)'
```

Not going to do this in the "block" format supported, I think repetition is easier.

Now lets try running this.

```
$ nextflow run ../helloDocker.nf -with-docker debian:latest

N E X T F L O W  ~  version 19.10.0
Launching `../helloDocker.nf` [lethal_sanger] - revision: 93932ef807
executor >  local (3)
[63/9c8d6b] process > splitLetters       [100%] 1 of 1 ✔
[04/d4e719] process > convertToUpper (1) [100%] 2 of 2 ✔
DOCKER
HELLO
```

OK, that actually worked! Note that it DID NOT SAY executor > docker! Lets see what the run command was:

```
grep "docker run"  work/63/9c8d6bf23cdd6195d49e662b3b7484/.command.run
docker run -i -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/63/9c8d6bf23cdd6195d49e662b3b7484:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/63/9c8d6bf23cdd6195d49e662b3b7484 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash -u $(id -u):$(id -g) --name $NXF_BOXID debian:latest -c "/bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerFat/work/63/9c8d6bf23cdd6195d49e662b3b7484/.command.sh"
```

Great!


## Running each step of the workflow out of a specific container

Now that we succeeded in running the entire workflow out of a specified container, what about running different steps out of different containers?

This requires per-process configuration in the config file. Makes sense as one nextflow workflow can come with one config file, and that config file defines how to run it. There are ways to configure multiple "profiles" in a config file so one config file can specify how to run on a cluster or the cloud; use docker or run locally, etc. I'm not going to use profiles here. The `-withDocker` option on the command line also has to go, as there is no default docker container, so if no container is specified, a process should run locally.

The user-wide defaults config file must be set as above for docker to work at all. Will create a new project and try to get docker to work per-process in that:

```
mkdir -p /path/to/LearningNextflow/Containers/DockerPart/
cd /path/to/LearningNextflow/Containers/DockerPart/
```

Create a nextflow.config file that has a `process` config section for the first step `splitLetters`

```
process {
    withName: splitLetters {
        container = 'debian:latest'
    }
}
```

And then try running it:

```
$ nextflow run ../helloDocker.nf

N E X T F L O W  ~  version 19.10.0
Launching `../helloDocker.nf` [drunk_swartz] - revision: 01109bce2f
executor >  local (3)
[3e/4f46e4] process > splitLetters       [100%] 1 of 1 ✔
[66/5d60e4] process > convertToUpper (1) [100%] 2 of 2 ✔
DOCKER
HELLO

```

That seemed to work. How was the first step run? Can check the command.run nxf_launch() function:

```
$ cat work/3e/4f46e45fb5bd2a32b5dbc5dbc74ddb/.command.run
...
nxf_launch() {
    /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/3e/4f46e45fb5bd2a32b5dbc5dbc74ddb/.command.sh
}
...
```

Oops. Did not run with docker. Lets try setting the `docker.enabled = true` flag in the config. The config is now:

```
process {
    withName: splitLetters {
        container = 'debian:latest'
    }
}

docker {
    enabled = true
}
```

It should run ...

```
$ nextflow run ../helloDocker.nf

N E X T F L O W  ~  version 19.10.0
Launching `../helloDocker.nf` [voluminous_ritchie] - revision: 01109bce2f
executor >  local (3)
[33/9bf95b] process > splitLetters       [100%] 1 of 1 ✔
[97/01ee5a] process > convertToUpper (1) [100%] 2 of 2 ✔
DOCKER
HELLO
```

Did that change anything?

```
cat work/33/9bf95b710b544b4d4221222ffdfba4/.command.run
...
nxf_launch() {
    docker run -i -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/33/9bf95b710b544b4d4221222ffdfba4:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/33/9bf95b710b544b4d4221222ffdfba4 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash -u $(id -u):$(id -g) --name $NXF_BOXID debian:latest -c "/bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/33/9bf95b710b544b4d4221222ffdfba4/.command.sh"
}
...
```

Yes. It ran with docker.

Lets hope the next steps did not...

```
$ cat work/97/01ee5ad6e557581697bc863c31d97d/.command.run
...
nxf_launch() {
    /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/97/01ee5ad6e557581697bc863c31d97d/.command.sh
}
...
```

Perfect; it ran alone. Now lets set the config to get this step to run in a different docker...

config file is now:
```
process {
    withName: splitLetters {
        container = 'debian:latest'
    }
    withName: convertToUpper {
        container = 'ubuntu:latest'
    }
}

docker {
    enabled = true
}
```

Lets see if that runs?

```
$ nextflow run ../helloDocker.nf

N E X T F L O W  ~  version 19.10.0
Launching `../helloDocker.nf` [pedantic_meitner] - revision: 01109bce2f
executor >  local (3)
[86/c62389] process > splitLetters       [100%] 1 of 1 ✔
[10/f54ab6] process > convertToUpper (2) [100%] 2 of 2 ✔
HELLO
DOCKER
```

Correctly?

```
$ cat work/86/c623898377a30000d45a4574022a87/.command.run
...
nxf_launch() {
    docker run -i -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/86/c623898377a30000d45a4574022a87:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/86/c623898377a30000d45a4574022a87 -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash -u $(id -u):$(id -g) --name $NXF_BOXID debian:latest -c "/bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/86/c623898377a30000d45a4574022a87/.command.sh"
}
...
```

First one ran with Debian latest. And the second?

```
$ cat work/10/f54ab6908d2d40122685b54d64ac5f/.command.run

...
nxf_launch() {
    docker run -i -v /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work:/home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work -v "$PWD":"$PWD" -w "$PWD" --entrypoint /bin/bash -u $(id -u):$(id -g) --name $NXF_BOXID ubuntu:latest -c "/bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/DockerPart/work/10/f54ab6908d2d40122685b54d64ac5f/.command.sh"
}
...
```

And that ran with Ubuntu. OK, so can run different processes with different docker containers. Only caveat is have to make sure to set `docker.enabled = true` also.


## Singularity

Lets try the same experiments above using singularity...

### Whole workflow from singularity at command line

```
$ mkdir -p Containers/SingularityFat
$ cp HelloWorld/helloWait.nf Containers/helloSingularity.nf
$ cd Containers
$ vi helloSingularity.nf
# Change the greeting string from "Hello world!" to "Hello Singularity!"

$ cd SingularityFat
$ nextflow run ../helloSingularity.nf -with-singularity debian:latest

N E X T F L O W  ~  version 19.10.0
Launching `../helloSingularity.nf` [distracted_bassi] - revision: d2b8dc215e
[-        ] process > splitLetters   -
[-        ] process > convertToUpper -
Pulling Singularity image docker://debian:latest [cache /home/srj/GitHub/Jefferyexecutor >  local (1)
[5b/53df22] process > splitLetters   [  0%] 0 of 1
[-        ] process > convertToUpper -
executor >  local (1)
[5b/53df22] process > splitLetters   [  0%] 0 of 1 ✔
[-        ] process > convertToUpper -
executor >  local (4)
[5b/53df22] process > splitLetters       [100%] 1 of 1 ✔
[17/4b3505] process > convertToUpper (3) [  0%] 0 of 3
executor >  local (4)
[5b/53df22] process > splitLetters       [100%] 1 of 1 ✔
[e6/a0ca72] process > convertToUpper (2) [100%] 3 of 3 ✔
Pulling Singularity image docker://debian:latest [cache /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityFat/work/singularity/debian-latest.img]
HELLO
ARITY!
SINGUL
WARN: Singularity cache directory has not been defined -- Remote image will be stored in the path: /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityFat/work/singularity
```

Wow, worked straight up. Lets see what it did:

```
$ cat work/5b
...
nxf_launch() {
    set +u; env - PATH="$PATH" SINGULARITYENV_TMP="$TMP" SINGULARITYENV_TMPDIR="$TMPDIR" singularity exec /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityFat/work/singularity/debian-latest.img /bin/bash -c "cd $PWD; /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityFat/work/5b/53df22e3f9fe4a8e2b5431e2f0afb7/.command.sh"
}
...

```

That looks OK. Not sure how it is mounting the directories I need to work with. It did read and write from the local directory and sub-directories.

There was also a warning about not having a cache directory defined. It saved the image to

```
$ ls -al ./work/singularity
-rwxr-xr-x. 1 srj shiny 47173663 Feb  7 19:53 debian-latest.img
```

Defining a cache directory requires using an environmental variable or a config file, so lets look there next

### Whole workflow with singularity from a config file.

The main singularity config options are:

**`enabled`**` = true - `Set this to allow singularity processing.
**`engineOptions`**` = "<string>"	- `Provide arbitrary options after the `singularity` command.
**`runOptions`**` = "<string>" - `Provide arbitrary options after the `singularity exec` command.
**`autoMounts`**` = true - `Automatically mount host paths into the executed container (requires singularity to allow that).
**`cacheDir`**` = <path> - `Cache singularity images here.
**`noHttps`**` = true - `Force pulling singularity image via http and not https.
**`pullTimeout`**` = <int> `Time at which a long-running `singularity pull` will be terminated. Default is 20 min. [TODO: What unit is this, or how are units specified?].
**`envWhitelist`**` = "<env,env,...>" - `Comma separated list of environment variable names to be exported into the container environment.

Creating the following config file in Containers/SingularityFat/

```
process.container = 'debian:latest'

singularity {
    enabled = true
    cacheDir = '/datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs'
    autoMounts = true
}
```

And then run with bland command line:

```
$ nextflow run ../helloSingularity.nf

N E X T F L O W  ~  version 19.10.0
Launching `../helloSingularity.nf` [infallible_jennings] - revision: d2b8dc215e
[-        ] process > splitLetters   -
executor >  local (1)
executor >  local (1)
executor >  local (4)
executor >  local (4)
executor >  local (4)
[8d/e4887d] process > splitLetters       [100%] 1 of 1 ✔
[84/37e838] process > convertToUpper (1) [100%] 3 of 3 ✔
Pulling Singularity image docker://debian:latest [cache /datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/debian-latest.img]
SINGUL
ARITY!
HELLO
```

Yup, looked like that worked.

```
cat work/8d/e4887d7cf4538ea1f9fa0f452fce9d/.command.run

nxf_launch() {
    set +u; env - PATH="$PATH" SINGULARITYENV_TMP="$TMP" SINGULARITYENV_TMPDIR="$TMPDIR" singularity exec -B /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityFat/work/8d/e4887d7cf4538ea1f9fa0f452fce9d -B "$PWD" /datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/debian-latest.img /bin/bash -c "cd $PWD; /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityFat/work/8d/e4887d7cf4538ea1f9fa0f452fce9d/.command.sh"
}
```

The `automounts = true` caused some `-B` bindings to be added that were missing in the previous call, not sure how it worked without them, although everything is in my home directory, so that may be mounted by default into the singularity container.

### Singularity and per-process execution

OK, lets create a new directory for the partial singularity run

```
cd ..
mkdir SingularityHalf
cd SingularityHalf
```

And the required nextflow.config file

```
process {
    withName: splitLetters {
        container = 'debian:latest'
    }
}

singularity {
    enabled = true
    cacheDir = '/datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs'
    autoMounts = true
}
```

This should pull from the cache instead of dockerhub. Lets see what we get

```
$ nextflow run ../helloSingularity.nf

N E X T F L O W  ~  version 19.10.0
Launching `../helloSingularity.nf` [gloomy_ekeblad] - revision: d2b8dc215e
executor >  local (4)
[2e/823394] process > splitLetters       [100%] 1 of 1 ✔
[64/13c1a8] process > convertToUpper (2) [100%] 3 of 3 ✔
ARITY!
SINGUL
```

Looks good. And what it ran...

```
$ cat work/2e/823394400b1840d0cddf16262887c2/.command.run

...
nxf_launch() {
    set +u; env - PATH="$PATH" SINGULARITYENV_TMP="$TMP" SINGULARITYENV_TMPDIR="$TMPDIR" singularity exec -B /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityHalf/work/2e/823394400b1840d0cddf16262887c2 -B "$PWD" /datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/debian-latest.img /bin/bash -c "cd $PWD; /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityHalf/work/2e/823394400b1840d0cddf16262887c2/.command.sh"
}
...
```

First step ran with singularity.

```
$ cat work/64/13c1a82a9f99f52156f02007c741df/.command.run

...
nxf_launch() {
    /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularityHalf/work/64/13c1a82a9f99f52156f02007c741df/.command.sh
}
...
```

Second step ran local. Cool

## Singularity and Slurm

Final step instead of just repeating the "two different containers" example from above, I'm going to try to do two different containers on slurm, but submit to slurm.

Will still use the helloSingularity.nf workflow, but will need a new run directory and config file:

```
$ cd ..
$ mkdir SingularitySlurm
$ cd SingularitySlurm
```

*nextflow.config*
```
process {
    withName: splitLetters {
        container = 'debian:latest'
    }
    withName: convertToUpper {
        container = 'ubuntu:latest'
    }
    executor = 'slurm'
    cpus = 2
    memory = 4.GB
}

singularity {
    enabled = true
    cacheDir = '/datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs'
    autoMounts = true
}
```

```
$ nextflow run ../helloSingularity.nf

N E X T F L O W  ~  version 19.10.0
Launching `../helloSingularity.nf` [berserk_ptolemy] - revision: d2b8dc215e
executor >  slurm (1)
executor >  slurm (3)
executor >  slurm (4)
executor >  slurm (4)
executor >  slurm (4)
[52/7a555f] process > splitLetters       [100%] 1 of 1 ✔
[ba/63d38b] process > convertToUpper (1) [100%] 3 of 3 ✔
ARITY!
SINGUL
HELLO

Completed at: 07-Feb-2020 16:12:36
Duration    : 1m 20s
CPU hours   : (a few seconds)
Succeeded   : 4

```

That looks great.

From .nextflow.log
```
...
Feb-07 16:11:16.637 [Actor Thread 4] DEBUG nextflow.container.SingularityCache - Singularity found local store for image=docker://debian:latest; path=/datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/debian-latest.img
Feb-07 16:11:16.804 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process splitLetters > jobId: 1484051; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/52/7a555f06b7244c8865070870e57a2a
...
Feb-07 16:11:56.517 [Actor Thread 1] INFO  nextflow.container.SingularityCache - Pulling Singularity image docker://ubuntu:latest [cache /datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/ubuntu-latest.img]
Feb-07 16:12:00.037 [Actor Thread 1] DEBUG nextflow.container.SingularityCache - Singularity pull complete image=docker://ubuntu:latest path=/datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/ubuntu-latest.img
Feb-07 16:12:00.096 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process convertToUpper (1) > jobId: 1484052; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/ba/63d38b213c28327d7e724cac1b7ddb
Feb-07 16:12:00.097 [Task submitter] INFO  nextflow.Session - [ba/63d38b] Submitted process > convertToUpper (1)
Feb-07 16:12:00.135 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process convertToUpper (3) > jobId: 1484053; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/b8/e854aa069cb440540bed71e219fe6d
Feb-07 16:12:00.135 [Task submitter] INFO  nextflow.Session - [b8/e854aa] Submitted process > convertToUpper (3)
Feb-07 16:12:00.173 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process convertToUpper (2) > jobId: 1484054; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/6b/f2dc1c1b75b75bcead3994a3e24862
Feb-07 16:12:00.174 [Task submitter] INFO  nextflow.Session - [6b/f2dc1c] Submitted process > convertToUpper (2)
...
```

From the first .command.run

```
$ cat work/52/7a555f06b7244c8865070870e57a2a/.command.run

#!/bin/bash
#SBATCH -D /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/52/7a555f06b7244c8865070870e57a2a
#SBATCH -J nf-splitLetters
#SBATCH -o /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/52/7a555f06b7244c8865070870e57a2a/.command.log
#SBATCH --no-requeue
#SBATCH -c 2
#SBATCH --mem 4096M
# NEXTFLOW TASK: splitLetters
set -e
...
nxf_launch() {
    set +u; env - PATH="$PATH" SINGULARITYENV_TMP="$TMP" SINGULARITYENV_TMPDIR="$TMPDIR" singularity exec -B /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/52/7a555f06b7244c8865070870e57a2a -B "$PWD" /datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/debian-latest.img /bin/bash -c "cd $PWD; /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/52/7a555f06b7244c8865070870e57a2a/.command.sh"
}
...
```

Ran in a Debian singularity container as a slurm submitted job.

Likewise:

```
$ cat work/ba/63d38b213c28327d7e724cac1b7ddb/.command.run

#!/bin/bash
#SBATCH -D /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/ba/63d38b213c28327d7e724cac1b7ddb
#SBATCH -J nf-convertToUpper_(1)
#SBATCH -o /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/ba/63d38b213c28327d7e724cac1b7ddb/.command.log
#SBATCH --no-requeue
#SBATCH -c 2
#SBATCH --mem 4096M
# NEXTFLOW TASK: convertToUpper (1)
set -e
...
nxf_launch() {
    set +u; env - PATH="$PATH" SINGULARITYENV_TMP="$TMP" SINGULARITYENV_TMPDIR="$TMPDIR" singularity exec -B /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work -B "$PWD" /datastore/nextgenout5/share/labs/bioinformatics/srj/Simgs/ubuntu-latest.img /bin/bash -c "cd $PWD; /bin/bash -ue /home/srj/GitHub/Jefferys/LearningNextflow/Containers/SingularitySlurm/work/ba/63d38b213c28327d7e724cac1b7ddb/.command.sh"
}
...
```

Ran in a Ubuntu container as a slurm submitted job.

So that's it for containers. Questions left:

1. What if I have a process-specific container that needs its own options?

    There is a `containerOptions = "<String>"` process property. Setting that on the process allows per-process options. I'm pretty sure that is in ADDITION to any global settings, not instead of. There is actually a per-process `clusterOptions = "<string>"` setting also.

2. What if I want to run one process by Docker and one by Singularity?

    Ha - nobody does that. Might not be possible?

3. What if I want to run one process by Slurm and one by SGE?

    That might be possible with a per-process setting of "executor"