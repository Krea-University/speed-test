# TTY-Free Deployment Guide

This guide explains how to deploy the Krea Speed Test Server in environments without TTY support (like CI/CD pipelines, automation scripts, or restricted SSH sessions).

## 🚀 Quick Solutions

### Option 1: Use the --no-tty Flag
```bash
./deploy.sh --no-tty yourdomain.com admin@yourdomain.com
```

### Option 2: Use the No-TTY Wrapper
```bash
./deploy-no-tty.sh yourdomain.com admin@yourdomain.com
```

### Option 3: Environment Variable
```bash
export DOCKER_NONINTERACTIVE=1
./deploy.sh yourdomain.com admin@yourdomain.com
```

## 🔧 Management Scripts with No-TTY Support

All management scripts now support the `--no-tty` flag:

```bash
# Backup
./backup-now.sh --no-tty

# Restore
./restore.sh --no-tty backup_file.sql.gz

# SSL Renewal
./renew-ssl.sh --no-tty

# Status check (already TTY-free)
./status.sh
./logs.sh app
```

## 🤖 CI/CD Integration Examples

### GitHub Actions
```yaml
- name: Deploy Speed Test Server
  run: |
    export DOCKER_NONINTERACTIVE=1
    export DEBIAN_FRONTEND=noninteractive
    ./deploy-no-tty.sh ${{ secrets.DOMAIN }} ${{ secrets.EMAIL }}
```

### Jenkins Pipeline
```groovy
pipeline {
    agent any
    stages {
        stage('Deploy') {
            steps {
                sh '''
                    export DOCKER_NONINTERACTIVE=1
                    export DEBIAN_FRONTEND=noninteractive
                    ./deploy-no-tty.sh ${DOMAIN} ${EMAIL}
                '''
            }
        }
    }
}
```

### GitLab CI
```yaml
deploy:
  script:
    - export DOCKER_NONINTERACTIVE=1
    - export DEBIAN_FRONTEND=noninteractive
    - ./deploy-no-tty.sh $DOMAIN $EMAIL
```

### Docker-based Deployment
```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  -e DOCKER_NONINTERACTIVE=1 \
  -e DEBIAN_FRONTEND=noninteractive \
  ubuntu:22.04 \
  bash -c "./deploy-no-tty.sh yourdomain.com admin@yourdomain.com"
```

## 🛠️ Troubleshooting

### Error: "the input device is not a TTY"
This happens when Docker tries to allocate a pseudo-TTY but none is available.

**Solutions:**
1. Use `--no-tty` flag: `./deploy.sh --no-tty yourdomain.com`
2. Set environment: `export DOCKER_NONINTERACTIVE=1`
3. Use wrapper: `./deploy-no-tty.sh yourdomain.com`

### Error: "Cannot connect to the Docker daemon"
```bash
# Check Docker status
sudo systemctl status docker

# Start Docker if needed
sudo systemctl start docker
```

### Error: "docker-compose: command not found"
```bash
# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## 🔍 How It Works

The TTY detection works through multiple layers:

1. **Command Line Flag**: `--no-tty` forces non-interactive mode
2. **Environment Variable**: `DOCKER_NONINTERACTIVE=1` disables TTY
3. **Automatic Detection**: `[ -t 0 ]` checks if stdin is a terminal
4. **Fallback**: Always uses `-T` flag when in doubt

The `docker_exec()` function automatically chooses:
- `docker-compose exec` for interactive environments
- `docker-compose exec -T` for non-interactive environments

## 📝 Testing

Test your environment's TTY support:
```bash
# Run the TTY test
./test-tty.sh

# Test --no-tty functionality
./test-no-tty.sh

# Test in non-interactive mode
echo "test" | ./deploy.sh --no-tty yourdomain.com
```

## 🚨 Common Scenarios

### SSH without TTY allocation
```bash
ssh -T user@server "cd /path/to/speed-test-server && ./deploy-no-tty.sh domain.com"
```

### Automated scripts
```bash
#!/bin/bash
set -e
export DOCKER_NONINTERACTIVE=1
export DEBIAN_FRONTEND=noninteractive
./deploy.sh --no-tty "$1" "$2"
```

### Background processes
```bash
nohup ./deploy-no-tty.sh yourdomain.com admin@yourdomain.com > deploy.log 2>&1 &
```

This comprehensive approach ensures the deployment works in any environment, whether interactive or automated!
