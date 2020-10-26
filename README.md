# Test apply_default on aio ansible-deploy

## Quick start on Vexx instance(s)

1. Install git to clone this repository:

``` bash
sudo yum install -y git
```

2. Clone this repository and run the startup script:

``` bash
git clone http://github.com/tungstenfabric/tf-devstack
./tf-devstack/ansible/run.sh
```

3. Put in /homes/centos/.ssh required ssh-files

4. Upload tf-deployment-test on instance

5. Copy .ssh in tf-deployment-test directory

6. Build image

``` bash
tf-deployment-test/build-containers.sh
```

7. Start test

``` bash
tf-deployment-test/testrunner.sh
```