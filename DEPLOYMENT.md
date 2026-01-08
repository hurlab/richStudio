# richStudio Deployment Guide

This guide covers deploying richStudio on a remote server with Shiny Server.

## Prerequisites

- R (>= 4.0.0) installed on the server
- Shiny Server installed and running
- SSH access to the server
- Basic familiarity with terminal commands

## Quick Deployment (Recommended)

### Step 1: Copy Files to Server

From your local machine:

```bash
# Using scp
scp -r richStudioJH2/ user@server:/srv/shiny-server/richStudio

# Or using rsync (better for large files)
rsync -avz --progress richStudioJH2/ user@server:/srv/shiny-server/richStudio
```

### Step 2: Install Dependencies Using renv

SSH into the server and run:

```bash
# Navigate to the app directory
cd /srv/shiny-server/richStudio

# Switch to shiny user (important for Shiny Server)
sudo su - shiny -c "cd /srv/shiny-server/richStudio && R -e 'renv::restore()'"

# Compile C++ code
sudo su - shiny -c "cd /srv/shiny-server/richStudio && R -e 'Rcpp::compileAttributes()'"
```

**Why renv?**
- Creates project-local library at `.renv/library/`
- Isolated from other R projects
- Ensures reproducible environment
- Prevents package version conflicts

### Step 3: Set Permissions

```bash
# Ensure shiny user owns the app directory
sudo chown -R shiny:shiny /srv/shiny-server/richStudio

# Ensure proper permissions
sudo chmod -R 755 /srv/shiny-server/richStudio
```

### Step 4: Restart Shiny Server

```bash
sudo systemctl restart shiny-server
```

### Step 5: Verify Deployment

Visit: `http://your-server:3838/richStudio/`

---

## Alternative Methods

### Method A: Direct Install (Without renv)

If you prefer not to use renv:

```bash
cd /srv/shiny-server/richStudio

# Run the installation script as shiny user
sudo su - shiny -c "cd /srv/shiny-server/richStudio && Rscript install_dependencies.R"
```

This installs packages to `~/R/library` (user library).

### Method B: Manual Package Installation

```bash
# Install CRAN packages (including richCluster)
sudo su - shiny -c "R -e \"install.packages(c('shiny', 'shinydashboard', 'shinyjs', 'shinyWidgets', 'shinyjqui', 'dplyr', 'tidyverse', 'ggplot2', 'plotly', 'heatmaply', 'reshape2', 'rlang', 'DT', 'data.table', 'readxl', 'writexl', 'jsonlite', 'zip', 'stringdist', 'config', 'Rcpp', 'richCluster'), repos='https://cloud.r-project.org')\""

# Install GitHub packages
sudo su - shiny -c "R -e \"install.packages('remotes', repos='https://cloud.r-project.org')\""
sudo su - shiny -c "R -e \"remotes::install_github('guokai8/richR')\""
sudo su - shiny -c "R -e \"remotes::install_github('guokai8/bioAnno')\""

# Install Bioconductor packages
sudo su - shiny -c "R -e \"if (!requireNamespace('BiocManager', quietly = TRUE)) install.packages('BiocManager', repos='https://cloud.r-project.org')\""
sudo su - shiny -c "R -e \"BiocManager::install(c('AnnotationDbi', 'org.Hs.eg.db'), ask=FALSE)\""
```

---

## Testing Before Shiny Server

To test the app before deploying to Shiny Server:

```bash
cd /srv/shiny-server/richStudio/inst/application

# Run interactively (you'll need X11 forwarding or run with R --quiet)
R -e "shiny::runApp('.', port=3838)"
```

Press `Ctrl+C` to stop.

---

## Troubleshooting

### App Won't Load

Check Shiny Server logs:

```bash
# Main log
sudo tail -f /var/log/shiny-server.log

# App-specific log
sudo tail -f /var/log/shiny-server/richStudio-*.log
```

### Package Not Found Errors

1. Verify packages are installed where Shiny Server expects them:
```bash
sudo su - shiny -c "R -e '.libPaths()'"
```

2. If using renv, check the project library:
```bash
ls -la /srv/shiny-server/richStudio/.renv/library/
```

3. Reinstall dependencies:
```bash
cd /srv/shiny-server/richStudio
sudo su - shiny -c "R -e 'renv::restore()'"
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R shiny:shiny /srv/shiny-server/richStudio

# Fix permissions
sudo chmod -R 755 /srv/shiny-server/richStudio
```

### C++ Compilation Errors

```bash
# Ensure R development tools are installed
sudo apt-get install r-base-dev

# Recompile C++ attributes
cd /srv/shiny-server/richStudio
sudo su - shiny -c "R -e 'Rcpp::compileAttributes()'"
```

---

## Package Locations Reference

| Method | Location | Notes |
|--------|----------|-------|
| **renv::restore()** | `.renv/library/` | Project-local, isolated |
| install_dependencies.R | `~/R/library` | User library, shared |
| System install | `/usr/lib/R/library` | System-wide, not recommended |

---

## Updating the App

To update richStudio on the server:

```bash
# 1. Copy new files
rsync -avz --progress richStudioJH2/ user@server:/srv/shiny-server/richStudio

# 2. Update dependencies if needed
sudo su - shiny -c "cd /srv/shiny-server/richStudio && R -e 'renv::restore()'"
sudo su - shiny -c "cd /srv/shiny-server/richStudio && R -e 'Rcpp::compileAttributes()'"

# 3. Restart Shiny Server
sudo systemctl restart shiny-server
```

---

## Server Configuration (Optional)

For custom Shiny Server configuration, edit:

```bash
sudo nano /etc/shiny-server/shiny-server.conf
```

Example site configuration:

```r
# /etc/shiny-server/shiny-server.conf
server {
  listen 3838;

  location /richStudio {
    app_dir /srv/shiny-server/richStudio/inst/application;
    log_dir /var/log/shiny-server;

    # Run as shiny user
    run_as shiny;

    # Optional: Disable bookmarking for security
    disable_bookmarking TRUE;
  }
}
```

After configuration changes:

```bash
sudo systemctl restart shiny-server
```

---

## Security Considerations

1. **File Permissions**: Ensure sensitive data files are not accessible
2. **Network Access**: Consider firewall rules for port 3838
3. **HTTPS**: Use reverse proxy (nginx/Apache) for SSL/TLS
4. **Authentication**: Add authentication if needed (see Shiny Server docs)

---

## Maintenance

### Regular Updates

```bash
# Update R packages
cd /srv/shiny-server/richStudio
sudo su - shiny -c "R -e 'renv::update()'"
```

### Backup

```bash
# Backup the entire app directory
tar -czf richstudio-backup-$(date +%Y%m%d).tar.gz /srv/shiny-server/richStudio
```

---

## Useful Commands

```bash
# Check Shiny Server status
sudo systemctl status shiny-server

# Restart Shiny Server
sudo systemctl restart shiny-server

# View real-time logs
sudo journalctl -u shiny-server -f

# Check R version
R --version

# List installed packages
sudo su - shiny -c "R -e 'installed.packages()[,c(\"Package\", \"Version\")]'"
```

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/hurlab/richStudio/issues
- richCluster Package: https://github.com/hurlab/richCluster (now on CRAN)
