# The Slurm Executor

## HelloSlurm

Can I run the hello world program on Slurm? And how do I do that.

The executor can be set on a per-process basis with a directive, or by default for all processes via the config file. Actually, this is just nested property setting, where the config file can have a `process` block where values can be set, and each process in the workflow can have the individual values set as directives. The config file defaults can also be over-ridden on the command line by setting a `-process.*` value, e.g. `-process.executor slurm`.

### Running HelloWorld with a different executor

```
$ nextflow run -process.executor slurm helloSlurm.nf

N E X T F L O W  ~  version 19.10.0
Launching `helloSlurm.nf` [angry_mccarthy] - revision: aeb346fd7b
executor >  slurm (3)
[46/5cfe6d] process > splitLetters       [100%] 1 of 1 ✔
[2d/304e25] process > convertToUpper (1) [100%] 2 of 2 ✔
STUART
HELLO
```

Yup, that worked!

#### What do the innards look like?

Looks like the only difference in the layout of the internals is the run script in the work directory

```
$ ls -al
-rw-r--r--. 1 srj shiny  372 Feb  3 21:52 helloSlurm.nf
drwxr-xr-x. 3 srj shiny 4096 Feb  3 21:57 .nextflow
-rw-r--r--. 1 srj shiny 6353 Feb  3 21:57 .nextflow.log
drwxr-xr-x. 5 srj shiny 4096 Feb  3 21:57 work
```

* **`.nextflow.log`**

    Traces the processing, including job submissions:
    
    ```
    ...
    Feb-03 16:57:24.604 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process splitLetters > jobId: 1478486; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/work/46/5cfe6dfe432479badad3765f2a7016
    Feb-03 16:57:24.610 [Task submitter] INFO  nextflow.Session - [46/5cfe6d] Submitted process > splitLetters
    Feb-03 16:57:54.719 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 1478486; id: 1; name: splitLetters; status: COMPLETED; exit: 0; error: -; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/work/46/5cfe6dfe432479badad3765f2a7016 started: 1580767045003; exited: 2020-02-03T21:57:25.365184Z; ]
    Feb-03 16:57:55.309 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process convertToUpper (2) > jobId: 1478487; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/work/77/e463a426179c5973eae3a622e8cc0d
    Feb-03 16:57:55.397 [Task submitter] INFO  nextflow.Session - [77/e463a4] Submitted process > convertToUpper (2)
    Feb-03 16:57:55.704 [Task submitter] DEBUG nextflow.executor.GridTaskHandler - [SLURM] submitted process convertToUpper (1) > jobId: 1478488; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/work/2d/304e25a90d0830189fe8a6f38117ca
    Feb-03 16:57:55.704 [Task submitter] INFO  nextflow.Session - [2d/304e25] Submitted process > convertToUpper (1)
    Feb-03 16:57:59.719 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 1478487; id: 3; name: convertToUpper (2); status: COMPLETED; exit: 0; error: -; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/work/77/e463a426179c5973eae3a622e8cc0d started: 1580767079711; exited: 2020-02-03T21:57:56.22621Z; ]
    Feb-03 16:57:59.731 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[jobId: 1478488; id: 2; name: convertToUpper (1); status: COMPLETED; exit: 0; error: -; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/work/2d/304e25a90d0830189fe8a6f38117ca started: 1580767079726; exited: 2020-02-03T21:57:56.239204Z; ]
    Feb-03 16:57:59.734 [main] DEBUG nextflow.Session - Session await > all process finished
    ...
    ```

* **`.nextflow/*`**

    This is all the same internals. Surprisingly there is no apparent change with the slurm executor.
    
    ```
    $ ls -al
    drwxr-xr-x. 3 srj shiny 4096 Feb  3 21:57 cache
    -rw-r--r--. 1 srj shiny  163 Feb  3 21:57 history
    
    $ cat history
    2020-02-03 16:57:16     44s     angry_mccarthy  OK      aeb346fd7bdf6489fda156ebf25d7e8a        2dfdbd0c-2ca6-4d99-8187-3df1ca512b60    nextflow run -process.executor slurm helloSlurm.nf

    $ ls -al cache
    drwxr-xr-x. 3 srj shiny 4096 Feb  3 22:24 2dfdbd0c-2ca6-4d99-8187-3df1ca512b60
    
    $ ls -al cache/2dfdbd0c-2ca6-4d99-8187-3df1ca512b60
    drwxr-xr-x. 2 srj shiny 4096 Feb  3 22:24 db
    -rw-r--r--. 1 srj shiny   51 Feb  3 21:57 index.angry_mccarthy
    
    $ ls -al cache/2dfdbd0c-2ca6-4d99-8187-3df1ca512b60/db
    -rw-r--r--. 1 srj shiny 1856 Feb  3 21:57 000003.log
    -rw-r--r--. 1 srj shiny   16 Feb  3 21:57 CURRENT
    -rw-r--r--. 1 srj shiny    0 Feb  3 21:57 LOCK
    -rw-r--r--. 1 srj shiny   50 Feb  3 21:57 MANIFEST-000002
    ```

* **`work/`**

    Structured like before, based on process-run id.
    
    ```
    $ ls -al
    drwxr-xr-x. 3 srj shiny 4096 Feb  3 21:57 2d
    drwxr-xr-x. 3 srj shiny 4096 Feb  3 21:57 46
    drwxr-xr-x. 3 srj shiny 4096 Feb  3 21:57 77
    ```
    
* **`work/<run/uid>/`**
    
    Structured like before
    
    ```
    $ ls -al 2d/304e25a90d0830189fe8a6f38117ca/
    lrwxrwxrwx. 1 srj shiny  100 Feb  3 21:57 chunk_aa -> /path/to/SlurmExec/work/46/5cfe6dfe432479badad3765f2a7016/chunk_aa
    -rw-r--r--. 1 srj shiny    0 Feb  3 21:57 .command.begin
    -rw-r--r--. 1 srj shiny    0 Feb  3 21:57 .command.err
    -rw-r--r--. 1 srj shiny    6 Feb  3 21:57 .command.log
    -rw-r--r--. 1 srj shiny    6 Feb  3 21:57 .command.out
    -rw-r--r--. 1 srj shiny 2750 Feb  3 21:57 .command.run
    -rw-r--r--. 1 srj shiny   50 Feb  3 21:57 .command.sh
    -rw-r--r--. 1 srj shiny    1 Feb  3 21:57 .exitcode
    
    Files are the same, except for the .command.run
    
* **`work/<run/uid>/.command.run`**
    
    This is similar to the local executor, but it wraps the previous "local" run script in a slurm batch submit wrapper, so it starts with
    
    ```
    #!/bin/bash
    #SBATCH -D /path/to/SlurmExec/work/2d/304e25a90d0830189fe8a6f38117ca
    #SBATCH -J nf-convertToUpper_(1)
    #SBATCH -o /path/to/SlurmExec/work/2d/304e25a90d0830189fe8a6f38117ca/.command.log
    #SBATCH --no-requeue
    # NEXTFLOW TASK: convertToUpper (1)
    ...
    ```
    
    The rest of the run script is the same. This is really nice symmetry under the covers!!!

## Setting it to run on slurm using a config file

Just like the param object can have its properties set in the config file, the process object can also. This is described in more detail (here)[https://www.nextflow.io/docs/latest/config.html#scope-process]




```
mkdir SlurmConfig
cp helloSlurm.nf SlurmConfig/
cd SlurmConfig
vi nextflow.config
...
```

Set up `nextflow.config` file to look like:
```
process {
    executor = 'slurm'
    cpus = 2
    memory = 8 GB
    time = 5 m
}
```

Run with simple nextflow command

```
nextflow run helloSlurm.nf

N E X T F L O W  ~  version 19.10.0
Launching `helloSlurm.nf` [crazy_celsius] - revision: aeb346fd7b
executor >  slurm (3)
[de/49d3ae] process > splitLetters       [100%] 1 of 1 ✔
[6f/115710] process > convertToUpper (2) [100%] 2 of 2 ✔
HELLO
STUART
Completed at: 04-Feb-2020 15:06:32
Duration    : 1m 12s
CPU hours   : (a few seconds)
Succeeded   : 3
```

The appropriate parameters are present in the run script:

```
head cd work/de/49d3aeb1104ad6c8917efe9e458c88/.command.run
#!/bin/bash
#SBATCH -D /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/SlurmConfig/work/de/49d3aeb1104ad6c8917efe9e458c88
#SBATCH -J nf-splitLetters
#SBATCH -o /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/SlurmConfig/work/de/49d3aeb1104ad6c8917efe9e458c88/.command.log
#SBATCH --no-requeue
#SBATCH -c 2
#SBATCH --mem 8192M
# NEXTFLOW TASK: splitLetters
...
```

## Slurm executor / process parameters

Process and executor parameters can be set in multiple places, where they are most naturally set depends on the parameter. Setting the executor to run on slurm makes sense as a setting for the whole workflow, but it is applied at the step level so different steps can be run with different executors [TODO: Is that TRUE?]. Other settings make more sense to be set on the process/step level, e.g. resources settings like cpu, memory, and time. For a slurm executor, the specific options that can be set are:


* **`clusterOptions`**` = '<string of options>'`

    Any parameter that can be passed to slurm can be specified by setting this in the process block (or passed to the command line). [TODO: How does this work? The example given is `clusterOptions = '-pe smp 10 -l virtual_free=64G,h_rt=30:00:00'`]
    
* **`queue`**` = '<partition>'`
    Partition of the slurm cluster to submit to.

* **`cpus`**` = '<int>'`
    Number of cpus for the process as submitted

* **`memory`**` = '<int>. B | KB | MB | GB | TB'`
    Memory limit for the process as submitted, in bytes, kilobytes, megabytes, gigabytes, or terabytes. [TODO:: default]

* **`time`**` = '<int>. s | m | h | d'`
    Time limit for the process as submitted, in seconds, minutes, hours, or days. [TODO:: default]

## Executing nextflow in batch mode 

### What happens if you close the terminal running nextflow before it finishes?

```
$ mkdir HelloWait
$ cp helloWorld.nf HelloWait/helloWait.nf
$ cd HelloWait
$ vi HelloWait.nf
```

Edit the two scripts so they have a sleep 5 line before and after them, e.g.

```
"""
    sleep 5
    printf '${params.str}' | split -b 6 - chunk_
    sleep 5
"""
```

Now open a second terminal to this directory, run nextflow redirecting output to a file, and immediately close the terminal.

```
$ nextflow run helloWait.nf > nf.out
# CLOSE TERMINAL
```

Logging back in and checking output file shows this causes the workflow to abort:

```
$ cat nf.out
N E X T F L O W  ~  version 19.10.0
Launching `helloWait.nf` [kickass_heisenberg] - revision: 93932ef807
[-        ] process > splitLetters -

[-        ] process > splitLetters   -
[-        ] process > convertToUpper -

executor >  local (1)
[e0/3aa78d] process > splitLetters   [  0%] 0 of 1
[-        ] process > convertToUpper -

executor >  local (1)
[e0/3aa78d] process > splitLetters   [100%] 1 of 1, failed: 1 ✘
[-        ] process > convertToUpper -
```

The `.nextflow.log` file also shows the failure due to SIGHUP:

```
Feb-04 17:40:01.686 [main] DEBUG nextflow.cli.Launcher - $> nextflow run helloWait.nf
Feb-04 17:40:02.914 [main] INFO  nextflow.cli.CmdRun - N E X T F L O W  ~  version 19.10.0
Feb-04 17:40:02.993 [main] INFO  nextflow.cli.CmdRun - Launching `helloWait.nf` [kickass_heisenberg] - revision: 93932ef807
...
Feb-04 17:40:06.884 [Task submitter] INFO  nextflow.Session - [e0/3aa78d] Submitted process > splitLetters
Feb-04 17:40:08.234 [SIGHUP handler] DEBUG nextflow.Session - Session aborted -- Cause: SIGHUP
Feb-04 17:40:08.253 [Task monitor] DEBUG n.processor.TaskPollingMonitor - Task completed > TaskHandler[id: 1; name: splitLetters; status: COMPLETED; exit: 129; error: -; workDir: /home/srj/GitHub/Jefferys/LearningNextflow/SlurmExec/HelloWait/work/e0/3aa78dc1dc7d02c6618f4f9091fccb]
Feb-04 17:40:08.265 [SIGHUP handler] DEBUG nextflow.Session - The following nodes are still active:
[process] convertToUpper
  status=ACTIVE
  port 0: (queue) OPEN  ; channel: x
  port 1: (cntrl) -     ; channel: $

Feb-04 17:40:08.269 [main] DEBUG nextflow.Session - Session await > all process finished
Feb-04 17:40:08.270 [main] DEBUG nextflow.Session - Session await > all barriers passed
Feb-04 17:40:08.287 [main] DEBUG nextflow.trace.StatsObserver - Workflow completed > WorkflowStats[succeedCount=0; failedCount=1; ignoredCount=0; cachedCount=0; succeedDuration=0ms; failedDuration=1.3s; cachedDuration=0ms]
Feb-04 17:40:08.511 [main] DEBUG nextflow.CacheDB - Closing CacheDB done
Feb-04 17:40:08.658 [main] DEBUG nextflow.script.ScriptRunner - > Execution complete -- Goodbye
```

There is no clear signal that things failed though... :(

### What happens if you close the terminal running nextflow in nohup before it finishes?

Lets try that again, but run it as:

```
$ nohup nextflow run helloWait.nf &
# CLOSE TERMINAL
```

This seemed to work fine!

```
$ cat nohup.out
N E X T F L O W  ~  version 19.10.0
Launching `helloWait.nf` [adoring_lamarr] - revision: 93932ef807
[-        ] process > splitLetters   -
[-        ] process > convertToUpper -

executor >  local (1)
[64/73bf1f] process > splitLetters   [  0%] 0 of 1
[-        ] process > convertToUpper -

executor >  local (1)
[64/73bf1f] process > splitLetters   [100%] 1 of 1 ✔
[-        ] process > convertToUpper -

executor >  local (3)
[64/73bf1f] process > splitLetters       [100%] 1 of 1 ✔
[15/84abd4] process > convertToUpper (1) [  0%] 0 of 2

executor >  local (3)
[64/73bf1f] process > splitLetters       [100%] 1 of 1 ✔
[15/84abd4] process > convertToUpper (1) [100%] 2 of 2 ✔
STUART
HELLO
```
