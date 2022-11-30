# ssh-tools
Get your git in order

## Instructions
### 1.) Install and Setup SSH for Windows

To Setup and Install Open SSH for Windows start follow script:

- at Powershell use command `OpenSSH-Install.ps1`
- at File Explorer click on `OpenSSH-Install.cmd`

![install-ssh](/img/install-ssh.jpg)

### 2.) Create SSH Keys
This step is Optional to creating new SSH Keys. When you have some SSH Keys plese jump Step 3.

For creatins SSH Keys use follow scripts:
- at Powershell use command `SSHKey-create.ps1`
- at File Explorer click on `SSHKey-create.cmd`

![create-ssh-key](/img/create-ssh-key.jpg)

> Repeate this for all need SSH Keys

### 3. ADD know SSH Hosts and other Options
Now you must add the Know SSH Hosts.

#### For adding and removing:
- you can add all hosts to the file `ssh_hosts.config` for comfort

![ssh hosts](/img/ssh_host-config.jpg)
##### Adding
- at Powershell use command `KnownSSHHosts-Add.ps1`
- at File Explorer click on `KnownSSHHosts-Add.cmd`

![add hosts](/img/add-host-cmd.jpg)

##### Removing
- at Powershell use command `KnownSSHHosts-Remove.ps1`
- at File Explorer click on `KnownSSHHosts-Remove.cmd`

![remove hosts](/img/remove-host-cmd.jpg)

### 4. ADD Registered SSH Keys and other Options
Now you must registered the Registered SSH Keys.

#### For Add and removing 
- you can add all Registered Keys to the file `ssh_keys.config` for comfort

![include file name](/img/include-file-name.jpg)
##### Adding
- at Powershell use command `RegisteredSSHKeys-Add.ps1`
- at File Explorer click on `RegisteredSSHKeys-Add.cmd`

![add ssh](/img/add-ssh.jpg)

#### Removing
- at Powershell use command `RegisteredSSHKeys-Remove.ps1`
- at File Explorer click on `RegisteredSSHKeys-Remove.cmd`

![remove ssh](/img/removing-ssh.jpg)