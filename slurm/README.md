# Slurm Workload Manager

[Slurm](https://slurm.schedmd.com/) is the de-facto scheduler for large HPC
jobs in supercomputer centers around the world. CoreWeave's Slurm
implementation integrates Slurm with Kubernetes, allowing compute to
transition between distributed training in Slurm and applications such as
online inference in Kubernetes.

**Please contact [CoreWeave support](https://cloud.coreweave.com/contact) when
interested in Slurm to receive engineering assistance in designing and
deploying your cluster.**

## Overview

SUNK(SlUrm oN Kubernetes) is an implementation of Slurm on Kubernetes deployed
on CoreWeave cloud, complete with options for an external Directory Service
such as Active Directory, Slurm Accounting backed by a MySQL database, and
dynamic Slurm node scaling to match your
workload requirements. In SUNK, Slurm images are derived from OCI container
images and execute on bare metal. Compute nodes resources are allocated using
Kubernetes. CoreWeave maintains several base images for different CUDA
versions including
[all dependencies for InfiniBand and SHARP](https://www.github.com/coreweave/nccl-tests).

## Features

- Full support for base Slurm job execution, such as srun / sbatch
- Full GRES support, automatic identification of GPUs and associated resources
- Dynamic Workers, compute nodes can be scaled up and down on demand
- Slurm Accounting, both locally deployed slurmdbd/MySQL or connecting to
  remote slurmdbd
- SSO, any LDAP compatible idP such as OpenLDAP, Okta and Active Directory
- cgroups for tracking and enforcement
- task/affinity for Slurm driven CPU co-location
- SSH to compute nodes as well as login node
- Mix GPU types and CPU-only nodes in the same cluster
- Images with CUDA, NCCL, InfinibBand, environment modules and conda available
  out of the box
- Build custom images and manage cluster deployment via CI and GitOps

## Prerequisites

- Please configure
  [storage volumes](https://docs.coreweave.com/storage/storage) to be used for
  home directory and data storage.
- An authentication service is necessary for production deployments. LDAP such
  as OpenLDAP, Okta and Active Directory is supported.

## Installing

The Slurm control-plane and compute nodes can be deployed via CoreWeave Apps
or as a Helm chart in a gitops workflow.

Installing the app with default values with defaults unchanged will provide a
functional Slurm environment, customization is likely desired.

The Slurm resources deployed by the chart should be finished and ready within
5-10 minutes.

```bash
$  kubectl get pods
NAME                                     READY   STATUS    RESTARTS   AGE
slurm-accounting-78b4fc659-mk8hx         4/4     Running   0          2d21h
slurm-controller-6849bd84c6-2bqc2        4/4     Running   6          2d21h
slurm-cpu-epyc-0                         4/4     Running   7          2d21h
slurm-cpu-epyc-1                         4/4     Running   6          2d21h
slurm-login-0                            4/4     Running   0          2d21h
slurm-mysql-0                            2/2     Running   1          2d21h
slurm-rest-5bc4bd587b-z5lzw              4/4     Running   0          2d21h
slurm-rtx4000-0                          4/4     Running   6          2d21h
slurm-rtx4000-1                          4/4     Running   6          2d21h
slurm-rtx4000-2                          4/4     Running   1          2d2h
slurm-rtx4000-3                          4/4     Running   1          2d2h
```

**NOTE:** None of the compute resources defined by default in the
`compute.nodes` section in `values.yaml` are enabled by default. Please see
the [Compute Node Definitions](#compute-node-definitions) section for further
details.

## Accessing Slurm

### SSH

If you have configured a Directory Service and the provided users are
configured for ssh access, you can SSH into the login node.

1. Find the IP address of the login Service, a DNS record is also created.

```bash
»  kubectl get svc slurm-login
NAME          TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)   AGE
slurm-login   LoadBalancer   10.135.201.138   207.53.234.11    22/TCP    2d21h
```

2. SSH into the Login Node

```bash
$  ssh tweldon@10.135.209.174
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.13.0-40-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.
Last login: Fri Nov  4 17:42:08 2022 from 10.145.65.75
tweldon@slurm-login-0:~$
```

### Kubectl Exec

If you have not configured a Directory Service, you will need to exec into the
Pod container.

```bash
$ kubectl exec -it slurm-login-0 -c sshd -- bash
root@slurm-login-0:/tmp#
```

### Running Slurm commands

Once logged in via SSH or Kubectl Exec, you can run Slurm commands and jobs:

```bash
root@slurm-login-0:~# srun -N 6 hostname
slurm-rtx4000-3
slurm-rtx4000-1
slurm-rtx4000-0
slurm-cpu-epyc-0
slurm-cpu-epyc-1
slurm-rtx4000-2
```

## Configuration

The following table lists the configurable parameters of the `slurm` chart and
their default values.

| Parameter                                          | Description                                                                                                                                                                                                                                                        | Default                                                             |
|----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| nodeSelector.region                                | The region set here is only for the slurm control-plane. Compute nodes should define their own affinities.                                                                                                                                                         | `LAS1`                                                              |
| directoryService.sudoGroups                        | List of groups from all directories with sudo privileges                                                                                                                                                                                                           | `""`                                                                |
| directoryService.directories[].name                | Name of directory service - `default` for primary directory                                                                                                                                                                                                        | `default`                                                           |
| directoryService.directories[].enabled             |                                                                                                                                                                                                                                                                    | `true`                                                              |
| directoryService.directories[].debugLevel          |                                                                                                                                                                                                                                                                    | `0x0200`                                                            |
| directoryService.directories[].ldapUri             |                                                                                                                                                                                                                                                                    | `""`                                                                |
| directoryService.directories[].user.bindDn         |                                                                                                                                                                                                                                                                    | `""`                                                                |
| directoryService.directories[].user.searchBase     |                                                                                                                                                                                                                                                                    | `""`                                                                |
| directoryService.directories[].user.password       |                                                                                                                                                                                                                                                                    | `""`                                                                |
| directoryService.directories[].user.canary         |                                                                                                                                                                                                                                                                    | `""`                                                                |
| directoryService.directories[].defaultShell        |                                                                                                                                                                                                                                                                    | `"/bin/bash"`                                                       |
| directoryService.directories[].fallbackHomeDir     |                                                                                                                                                                                                                                                                    | `"/home/%u"`                                                        |
| directoryService.directories[].overrideHomeDir     | Over-ride the `homeDirectory` attribute from LDAP                                                                                                                                                                                                                  | `""`                                                                |
| directoryService.directories[].ldapsCert           | Existing tls certificate for LDAP-S                                                                                                                                                                                                                                | `""`                                                                |
| directoryService.directories[].sudoGroups          | List of Unix groups enabled for sudo                                                                                                                                                                                                                               | `""`                                                                |
| directoryService.directories[].schema              | Desired LDAP schema                                                                                                                                                                                                                                                | `""`                                                                |
| directoryService.directories[].user.existingSecret | Name of existing secret containing an SSSD configuration snippet w/ the ldap_default_authtok set for the default domain. See the Directory Service section below for further details and an example.                                                               | `""`                                                                |
| slurmConfig.slurmCtld.timeout                      | The interval, in seconds, that the backup controller waits for the primary controller to respond before assuming control.                                                                                                                                          | `60`                                                                |
| slurmConfig.slurmCtld.prockTrackType               | proctrack/linuxproc or proctrack/cgroup(Requires special HPC security policy to use, please contact Coreweave support)                                                                                                                                             | `"proctrack/linuxproc" `                                            |
| slurmConfig.slurmCtld.taskPlugin                   | task/affinity or task/cgroups or task/                                                                                                                                                                                                                             | `"task/none" none`                                                  |
| slurmConfig.slurmd.timeout                         | The interval, in seconds, that the Slurm controller waits for slurmd to respond before configuring that node's state to DOWN.                                                                                                                                      | `30`                                                                |
| slurmConfig.slurmd.suspendTime                     | Pods which remain idle or down for this amount of time will be deleted                                                                                                                                                                                             | `INFINITE `                                                         |
| slurmConfig.inactiveLimit                          | The interval, in seconds, after which a non-responsive job allocation command (e.g. srun or salloc) will result in the job being terminated                                                                                                                        | `0`                                                                 |
| slurmConfig.killWait                               | The interval, in seconds, given to a job's processes between the SIGTERM and SIGKILL signals upon reaching its time limit.                                                                                                                                         | `30`                                                                |
| slurmConfig.waitTime                               | Specifies how many seconds the srun command should by default wait after the first task terminates before terminating all remaining tasks. The "--wait" option on the srun command line overrides this value. The default value is 0, which disables this feature. | `0`                                                                 |
| slurmConfig.selectTypeParameters                   |                                                                                                                                                                                                                                                                    | `CR_Core `                                                          |
| slurmConfig.defMemPerCPU                           | The default memory per CPU in megabytes. This value is used when the --mem-per-cpu option is not specified on the srun command line.                                                                                                                               | `4096`                                                              |
| slurmConfig.extraConfig                            | Freetext config to be appended to slurm.conf. Can be multiple lines.                                                                                                                                                                                               | `""`                                                                |
| network.disableK8sNetworking                       |                                                                                                                                                                                                                                                                    | `false`                                                             |
| network.vpcs                                       |                                                                                                                                                                                                                                                                    | `[]`                                                                |
| imagePullSecrets                                   |                                                                                                                                                                                                                                                                    | `[]`                                                                |
| controller.replicas                                |                                                                                                                                                                                                                                                                    | `1`                                                                 |
| controller.image.repository                        |                                                                                                                                                                                                                                                                    | `registry.gitlab.com/coreweave/sunk/slurmd`                         |
| controller.image.tag                               |                                                                                                                                                                                                                                                                    | `some-release`                                                      |
| controller.securityContext.runAsUser               | Default slurm userid                                                                                                                                                                                                                                               | `64030`                                                             |
| controller.securityContext.runAsGroup              |                                                                                                                                                                                                                                                                    | `64030`                                                             |
| controller.resources.limits.cpu                    |                                                                                                                                                                                                                                                                    | `4`                                                                 |
| controller.resources.limits.memory                 |                                                                                                                                                                                                                                                                    | `16Gi`                                                              |
| controller.resources.requests.cpu                  |                                                                                                                                                                                                                                                                    | `4`                                                                 |
| controller.resources.requests.memory               |                                                                                                                                                                                                                                                                    | `16Gi`                                                              |
| controller.terminationGracePeriodSeconds           |                                                                                                                                                                                                                                                                    | `10`                                                                |
| controller.priorityClassName                       |                                                                                                                                                                                                                                                                    | `spot`                                                              |
| login.replicas                                     |                                                                                                                                                                                                                                                                    | `1`                                                                 |
| login.image.repository                             |                                                                                                                                                                                                                                                                    | `registry.gitlab.com/coreweave/sunk/slurmd`                         |
| login.image.tag                                    |                                                                                                                                                                                                                                                                    | `some-release`                                                      |
| login.resources.limits.cpu                         |                                                                                                                                                                                                                                                                    | `4`                                                                 |
| login.resources.limits.memory                      |                                                                                                                                                                                                                                                                    | `8Gi`                                                               |
| login.resources.requests.cpu                       |                                                                                                                                                                                                                                                                    | `4`                                                                 |
| login.resources.requests.memory                    |                                                                                                                                                                                                                                                                    | `8Gi`                                                               |
| login.service.type                                 |                                                                                                                                                                                                                                                                    | `LoadBalancer`                                                      |
| login.service.externalTrafficPolicy                |                                                                                                                                                                                                                                                                    | `Local`                                                             |
| login.service.exposePublicIP                       |                                                                                                                                                                                                                                                                    | `false`                                                             |
| login.service.annotations                          |                                                                                                                                                                                                                                                                    | `{}`                                                                |
| login.terminationGracePeriodSeconds                |                                                                                                                                                                                                                                                                    | `10`                                                                |
| login.priorityClassName                            |                                                                                                                                                                                                                                                                    | `spot`                                                              |
| compute.ssh.enabled                                |                                                                                                                                                                                                                                                                    | `false`                                                             |
| compute.mounts                                     |                                                                                                                                                                                                                                                                    | `[]`                                                                |
| compute.partitions                                 |                                                                                                                                                                                                                                                                    | `PartitionName=all Nodes=ALL Default=YES MaxTime=INFINITE State=UP` |

## Compute Node Definitions

In SUNK it is possible to dynamically define compute nodes with exactly the
type and amount of compute resources required to execute your workloads.
There are several ways to define these nodes with an array of
preconfigured types provided in `values.yaml` by default. You are free to use
the provided definitions, create your own, or any desired combination. The
basis of all methods for defining compute nodes is a manifest such as:

```yaml
compute:
  # See "Shared Storage" below
  mounts: [ ]

  # See "s6" below
  s6: { }

  # See "Running Slurm Jobs in Containers" below
  pyxis:
    enabled: false

  partitions: |
    PartitionName=all Nodes=ALL Default=YES MaxTime=INFINITE State=UP # Partitions

  nodes:
    rtx4000: &template # Arbitrary node name
      enabled: false   # Can be defined, then toggled on or off
      replicas: 2      # Number of "nodes", specs defined below in "resources"

      features: # Slurm node feature flags
        - gpu
        - las1
        - cu117

      # See "Custom Images" below for information on building custom SUNK images. Once built may be specified here.
      image:
        repository: registry.gitlab.com/coreweave/sunk/slurmd-cw-cu117-extras

      # Extra environment variables, available within compute nodes
      env:
        - name: example
          value: "1"

      # Slurm Generic Resource Scheduling, should describe the type and number of your Generic Resource for this node type (rtx4000)
      gresGpu: quadro_rtx_4000:7

      # Kubernetes compute resources
      resources:
        limits:
          memory: 16Gi
          sunk.coreweave.com/accelerator: '7'
        requests:
          cpu: '8'
          memory: 16Gi
          sunk.coreweave.com/accelerator: '7'

      # Kubernetes affinities
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: topology.kubernetes.io/region
                    operator: In
                    values:
                      - LAS1 # CoreWeave deployment region
                  - key: gpu.nvidia.com/model
                    operator: In
                    values:
                      - Quadro_RTX_4000 # this node group is defined as "rtx4000", and so we probably want that GPU on our nodes. As such we must use Kubernetes node selectors to ensure we are scheduled to Kubernetes nodes with that GPU.
```

As you will see nothing about this definition should surprise anyone familiar
with typical yaml syntax. However, if you take a look at the `values.yaml`
file provided with this chart you will notice a very different syntax. The
equivilant of the above definition in that syntax would be:

```yaml
rtx4000-cu117:
  replicas: 2
  env:
    - name: example
      value: "1"
  definitions:
    - rtx4000
    - cu117
    - las1
```

What's going on here? Well since defining these nodesets quickly becomes a
tedious and verbose task, we have implemented a system for dynamically
layering definitions to provide instant composability and ease of use.

### Breaking it down:

When you add the `definitions` key to a compute node definition what you are
declaring that you would like to pull in either one of the pre-defined compute
definitions provided in the
[compute-defs](https://github.com/coreweave/sunk/tree/develop/charts/slurm/compute-defs)
directory, or another node definition you have defined in your `values.yaml`
file. For the sake of clarity we will refer to these different definitions
as "layers." If you take a look at one of the pre-provided layers in the
compute-defs directory it will look something like this:

```yaml
a4000:
  resources:
    limits:
      memory: 200Gi
      sunk.coreweave.com/accelerator: '7'
    requests:
      cpu: '32'
      memory: 200Gi
      sunk.coreweave.com/accelerator: '7'

  gresGpu: rtx_a4000:7

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: topology.kubernetes.io/region
                operator: In
                values:
                  - LAS1
              - key: gpu.nvidia.com/model
                operator: In
                values:
                  - RTX_A4000
```

The root key `a4000` is the name of the layer, and everything below it
constitutes the values which will be added to the layer when put into a node
definition. You may also notice that one layer stands out, `base.yaml`.
This layer is special in that it is applied to any node definition which
utilizes the `definitions` key. This is done to avoid having to constantly add
`- base` to your list of definitions while ensuring backwards compatibility if
you intend on not using layered definitions at all.

### Layering

When layers are defined they are applied in order to an object representing
the definition as it is being built. Each layer "updates" the object.
**IMPORTANT** this is not a simple merge or overwrite, but rather a
"deep update" of underlying values. The idea is that if a key is defined in
the object and the applied layer, instead of simply swapping the applied layer
for the existing, the object is recursively investigated to retain as much
information as possible. For example:

Base:
```yaml
my-node:
  features:
    - gpu
  resources:
    limits:
      memory: 200Gi
      sunk.coreweave.com/accelerator: '7'
```
Applied:
```yaml
my-other-layer:
  features:
    - las1
  resources:
    limits:
      memory: 100Gi # NOTE this is different than above
    requests:
      memory: 16Gi
      sunk.coreweave.com/accelerator: '7'
```
Gets composed into:
```yaml
my-node:
  features:
    - gpu
    - las1
  resources:
    limits:
      memory: 100Gi
      sunk.coreweave.com/accelerator: '7'
    requests:
      memory: 16Gi
      sunk.coreweave.com/accelerator: '7'
```

In essence the layering procedure attempts to see if there is any way to
relate keys to eachother, so for `features` given that it is a list of
strings, it will simply append the two sets of keys and output all the unique
values from it. With `resources` however, since it is a dictionary in which
the only common key is `limits.memory` only that key will be
explicitly overwritten, while the other keys will be merged together.

The following is a more complete list of behaviors:

- If the key represents a list of strings, the two lists will be merged
  together and all unique values will be output.
- If the key represents a dictionary, the procedure will recurse
- If the key represents a string, the value will be overwritten.
- If the key represents a list of key-value pairs, the procedure will
  determine if there is an identifying key (in this case, it is `name`) and if
  so, it will attempt to match the two lists by that key. If there is no
  match, the key will be appended to the list. If there is a match, the
  procedure will recurse and update corresponding values matched within the
  two matching list items.
- If the key represents a nodeAffinity object, the procedure assumes that a
  single matchexpression is desired and will update the match expression items
  by key.

The final behavior in this list is important. There is special handling in
place for affinities in particular to make it easier to quickly switch
definitions between regions, reserved instance identifiers, GPU/CPU types etc.
For example the `LGA` region layer looks like:

```yaml
lga1:
  features:
    - lga1
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: topology.kubernetes.io/region
                operator: In
                values:
                  - LGA1
```

If there was no special handling, the following would simply get appended to
the end of a node definition since the `name` key is not present in the list
items. But with the special handling, the `key` key is used to match the two
lists and the `values` key is updated to reflect the new region.

**Remember**: Layers are appllied in order, by default top to bottom

```
definitions:
  - rtx4000
  - cu117
  - las1
  - lga1
  - a4000
```

So this definition for example would result in an A4000 node in the LGA
region, instead of a rtx4000 node in the LAS region since the `las` and `lga`
layers as well as `rtx4000` and `a4000` layers respectively defined the same
values.

The final "layer" applied is anything defined alongside the `definitions` key
in the node definition. For example:

```yaml
compute:
  nodes:
    my-node:
      definitions:
        - rtx4000
        - cu117
        - las1
      resources:
        limits:
          memory: 100Gi
```

would compose the layers from the provided layers except it overwrite the
memory limit to 100Gi. This is useful for when you want to override a value
from a layer, or when you want to define a value which is not defined in any
layer.

### Layers as Values

Sometimes it is useful when customizing node definitions to create your own
layers. While the chart comes with a good selection of useful layer
definitions, it is possible that you may want your own to apply to multiple
definitions to keep your values file succinct. You may also wish to check in
your custom layers as separate values files. You are in luck, layers are just
custom values! So anything you define in your values file, or any values file
provided at templating time will be available to use as a layer. For example,
let's say in your values file you define the following:

```
compute:
  nodes:
    reservation-id:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node.coreweave.cloud/reserved
                    operator: In
                    values:
                      - <my-reservation-id>
```

You can then immediately use this as a layer in other definitions. For
example:

```
compute:
  nodes:
    reservation-id:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node.coreweave.cloud/reserved
                    operator: In
                    values:
                      - <my-reservation-id>
    my-node-def:
      definitions:
      - rtx4000
      - las1
      - cu117
      - reservation-id
    my-second-node-def:
      definitions:
      - a4000
      - lga1
      - cu120
      - reservation-id
```

Any key under `compute.nodes` can be used this way, even if that key is
another file.

## Shared Storage

It will likely be desirable to mount some or many different volumes of
shared/persistent storage that have been created outside of the SUNK Helm
Chart to your compute nodes, for one reason or another (code,
developer/researcher home directories, etc.). Such functionality is exposed
in SUNK via the `Compute.mounts` section of `values.yaml`, see the excerpt
below for an example:

```yaml
compute:
  mounts:
    - name: /mnt/nvme # mount path for shared volume (PVC)
      pvc: data-nvme # Name of a volume
    - name: /mnt/hdd
      pvc: data-hdd
```

## Running Scripts with s6

SUNK supports using [s6](https://skarnet.org/software/s6/),
specifically [s6-rc](https://skarnet.org/software/s6-rc/),
to run custom scripts on the compute nodes.

The scripts can be one of two types: `longrun`, or `oneshot`. As the names
imply, `longrun` is for scripts that continue to run as long as the compute
nodes are up, and `oneshot` is for scripts that are expected to terminate.

The scripts are defined in the `compute.s6` section of `values.yaml` with a
name, type, and bash script. See the excerpt below for an example.

```yaml
compute:
  s6:
    packages:
      type: oneshot
      script: |
        #!/usr/bin/env bash
        apt -y install nginx
    nginx:
      type: longrun
      script: |
        #!/usr/bin/env bash
        nginx -g "daemon off;"
```

In the example, two scripts are defined: `packages`, and `nginx`. The
first, `packages`, is a `oneshot` script that is used to install necessary
packages. In this case, `nginx`. Then the `longrun` script, `nginx`, starts
the web server process.

## Directory Service

It is possible to integrate with an external directory service such as AD for
user management. While a password field is supported in values, it is
recommended you configure the AD password with an existingSecret, and pass
the name of the secret to the
`directoryService.directories[].user.existingSecret` value. **Note:** this
secret has a number of requirements:

1. The key name must end in `.conf`
2. The secret data must contain a complete and valid SSSD configuration
   snippet containing the domain and `ldap_default_authtok` parameter, not
   just the LDAP password.

Example:

```
apiVersion: v1
kind: Secret
metadata:
  name: slurm-ldap-password
type: Opaque
stringData:
  ldap-password.conf: |-
    [domain/default]
    ldap_default_authtok = Ch4ng3M3!
```

## Google Secure LDAP

Integration with
[Google Secure LDAP](https://support.google.com/a/answer/9048516) as a
Directory Service is also supported.

To use Google as an LDAP provider, review
[their documentation](https://support.google.com/a/answer/9048434) on adding a
new LDAP client.

After the [generated certificate](https://support.google.com/a/answer/9100660)
has been downloaded, a secret of type `tls` will need to be created, E.G:

`kubectl create secret tls ldap-certificate --cert=Google_2025_08_24_55726.crt --key=Google_2025_08_24_55726.key`

With the secret created, your `directoryService` values should look something
like this:

```
directoryService:
  sudoGroups:
    - group1
  directories:
  - name: default
    enabled: true
    debugLevel: 0x0200
    ldapUri: ldaps://ldap.google.com:636
    defaultShell: "/bin/bash"
    fallbackHomeDir: "/home/%u"
    ldapsCert: ldap-certificate
    # For Google Secure LDAP, set schema: rfc2307bis
    schema: rfc2307bis
```

### SSH Keys with Google Secure LDAP

Users signed in with Google Secure LDAP can sign in via SSH key tied to their
account if the `sshPublicKey` attribute is set on the user's account.

To add custom attributes, review the
[Google Documentation](https://support.google.com/a/answer/6208725).

Create a multi-value attribute called `sshPublicKey` and populate the field on
each account with a desired public key.

Note: Google custom attribute values cannot exceed 500 characters, so it is
recommended to use a key of type `ssh-ed25519`.

## Custom Images

The default images build and published by CoreWeave have anything needed, but
it is likely you'll want to create custom images with additional software and
dependencies. SUNK supports using custom images for every part of the
deployment.

### Building Custom Images

Many of the ML related custom images used throughout CoreWeaves examples and
documentation are available in the
[ml-containers repo](https://github.com/coreweave/ml-containers).

In this repo there is an example for building custom SUNK images:
[Customization of SUNK Slurm Images](https://github.com/coreweave/ml-containers/tree/main/slurm).
There you'll also find an example of a
[Github action CI build](https://github.com/coreweave/ml-containers/blob/main/.github/workflows/slurm.yml)
for a custom login and compute image. The login node uses `controller-extras`
as the base image where the compute image uses `slurmd-cw-cu117-extras`.
Both images were originally created from
[Dockerfile.extras](../../images/slurm/Dockerfile.extras), but use different
base images. You can find those in the [.gitlab-ci.yml](../../.gitlab-ci.yml)
file.

**NOTE**: It is important that the entrypoint of `/init`, defined in
the [base Dockerfile](../../images/slurm/Dockerfile), is run. Be mindful if
you are overriding it with a different entrypoint in your custom image.

### Using Custom Images

SUNK supports using custom images for every part of the deployment. The two
that are likely wanted to be changed are the login node's and compute nodes'
images.

The login configuration where the image is defined is under the `login`
section of `values.yaml`. Here you can customize the image repository and tag:

```yaml
login:
  image:
    repository: custom-controller
    tag: 1.0.0
```

For every compute node defined under `compute.nodes`, you can change the image
repository and tag in the same way.

```yaml
compute:
  nodes:
    rtx4000-cu117:
      image:
        repository: custom-slurmd
        tag: 1.0.0
```

## Running Slurm Jobs in Containers

Slurm was popular long before Docker was released in 2013. Therefore, it
doesn't natively support running jobs on containers. Whatever your job needs
normally has to be installed on all the compute nodes.

[Pyxis](https://github.com/NVIDIA/pyxis), an open sourced SPANK plugin
developed by NVIDIA, solves this problem by giving you the ability to run your
slurm jobs within custom containers on your compute nodes.

**NOTE:** To run enroot/pyxis containers, a special Pod Security Policy needs
to be applied to the namespace that SUNK is deployed in. Contact CoreWeave
support for more information.

### Enabling Pyxis

To enable pyxis on SUNK, set the `compute.pyxis.enabled` value to `true`:

```yaml
compute:
  pyxis:
    enabled: true
```

Pyxis requires the [enroot](https://github.com/nvidia/enroot) container
utility to be installed, so SUNK will set that up as well. The
`compute.pyxis.mountHome` value corresponds to the `ENROOT_MOUNT_HOME` enroot
config variable. You can find an explanation for all of enroot's config
variables
[here](https://github.com/NVIDIA/enroot/blob/master/conf/enroot.conf.in).

Another requirement for using pyxis is setting additional security
capabilities on the compute nodes. This is done
by adding the following to the `compute` section of the `values.yaml`.

```yaml
compute:
  securityContext:
    capabilities:
      add: [ "SYS_NICE", "SYS_ADMIN" ]
```

### Enroot Credentials

In order to pull images, enroot uses a credentials file at
`$ENROOT_CONFIG_PATH/.credentials`. Here is an example of a credentials file:

```text
# NVIDIA GPU Cloud (both endpoints are required)
machine nvcr.io login $oauthtoken password <token>
machine authn.nvidia.com login $oauthtoken password <token>

# DockerHub
machine auth.docker.io login <login> password <password>

# Google Container Registry with OAuth
machine gcr.io login oauth2accesstoken password $(gcloud auth print-access-token)
# Google Container Registry with JSON
machine gcr.io login _json_key password $(jq -c '.' $GOOGLE_APPLICATION_CREDENTIALS | sed 's/ /\\u0020/g')

# Amazon Elastic Container Registry
machine 12345.dkr.ecr.eu-west-2.amazonaws.com login AWS password $(aws ecr get-login-password --region eu-west-2)

# Azure Container Registry with ACR refresh token
machine myregistry.azurecr.io login 00000000-0000-0000-0000-000000000000 password $(az acr login --name myregistry --expose-token --query accessToken  | tr -d '"')
# Azure Container Registry with ACR admin user
machine myregistry.azurecr.io login myregistry password $(az acr credential show --name myregistry --subscription mysub --query passwords[0].value | tr -d '"')

machine ghcr.io login <username> password <token>
```

### Using Pyxis

Once pyxis is installed all the slurm CLI commands for starting new jobs will
now support additional arguments.

In depth information can be found in
the [pyxis documentation](https://github.com/NVIDIA/pyxis#usage).

#### Downloading Image Files

When you start a slurm job using a container from an external registry, each
compute node will have to download the image. If the image is used for many
jobs, this download time starts to add up. To get around downloading the
image every time, you can save the image to a local file on one the shared
file system mounts. That way the local file will be available on every compute
node.

Saving the container is done with the `--container-save` argument. Once the
slurm job is complete, the container state is saved to a squashfs file.

This command saves the image to a local file:

```bash
srun --container-image=ghcr.io/coreweave/ml-containers/sd-finetuner:959f68a \
     --container-save=/mnt/nvme/images/sd-finetuner.sqsh \
     echo "hello world"
```

Adding a `--container-save` can be very useful on interactive jobs where you
are editing files. If the job was to fail for whatever reason, all of your
changes will be saved to the squashfs file.

```bash
srun --container-image=ghcr.io/coreweave/ml-containers/sd-finetuner:959f68a \
     --container-save=/mnt/nvme/images/sd-finetuner.sqsh \
     --pty /bin/bash
```

#### Mounting Directories

It is very common for a SUNK deployment to use shared PVCs mounted to the
login and compute nodes. If you also want jobs run via pyxis to have access to
these mounts in the same way, you need to use the `--container-mounts`
argument.

In this example, the `/mnt/nvme` folder on the compute nodes are mounted into
the image running the slurm job at `/mnt/nvme`. Doing this allows us to run
the `say_hello.sh` script that isn't built into the image.

```bash
srun --container-image=/mnt/nvme/custom_image.sqsh \
     --container-mounts=/mnt/nvme:/mnt/nvme
     /mnt/nvme/jobs/say_hello.sh
```

## Interacting with SUNK from Kubernetes

Since SUNK is deployed on top of kubernetes, it is important to know how to
interact with it from this perspective.

### Logging

Since Slurm daemons are running within pods, their logs can be accessed with
the `kubectl log` command.

**Controller logs:**
`kubectl logs -f -l app.kubernetes.io/name=slurmctld -c slurmctld`

**Slurmd logs:** `kubectl logs -f <compute pod name> -c slurmd`

### Restarting the Controller

While managing a SUNK cluster you might have to restart the slurm controller.
Doing so will not cancel active jobs, but could fix problems involving jobs
that are stuck pending.

To get the name of the controller deployment, run the following command:

```bash
kubectl get deployments -l app.kubernetes.io/component=controller
```

Since the controller pod is managed with a deployment, you can restart the
controller by running the following command:

```bash
kubectl rollout restart deployment <controller deployment name>
```

## Prolog and Epilog Scripts

Slurm supports configuring prolog and epilog scripts that will run at the
beginning and end of all jobs.

In SUNK, you can deploy prolog and epilog through a kubernetes config map.

### Deploying the Scripts

The config map containing the scripts needs to be deployed separately from
SUNK.

Each config map should contain all the scripts that will be run as
prologs/epilogs.

Below is an example configmap that defines a test prolog script.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: slurm-prolog
data:
  test.sh: |
    #!/usr/bin/env bash
    set -e

    echo "Prolog test executed"
```

### Configuring SUNK

In order for SUNK to use the scripts in the configmaps, the
`slurmConfig.slurmd.prologConfigmap` and `slurmConfig.slurmd.epilogConfigMap`
values in the values.yaml file need to be updated.

For example, if the two config maps are named `slurm-prolog` and
`slurm-epilog`, the values.yaml file should look like this:

```yaml
slurmConfig:
  slurmd:
    prologConfigMap: slurm-prolog
    epilogConfigMap: slurm-epilog
```
