# SPEC-WS-014 M2 test helpers: a local repository of tiny source packages, a fake downloader that
# honours the curl argument vector, an alternate allowlist and the installer's test-only config.
# Nothing here needs the network.

apk_fake_downloader <- '#!/usr/bin/env bash
out="" url="" i=0
args=("$@")
while (( i < $# )); do
  a=${args[i]}
  case $a in
    --output) out=${args[i+1]}; i=$((i+2)) ;;
    --max-time|--write-out|--proto|--proto-redir|--max-redirs) i=$((i+2)) ;;
    --*) i=$((i+1)) ;;
    *) url=$a; i=$((i+1)) ;;
  esac
done
printf "%s %s %s\\n" "$(date +%s.%N)" "$$" "$url" >> "$FAKE_DL_LOG"
mode=$(cat "$FAKE_DL_CTL/mode" 2>/dev/null || echo ok)
secs=$(cat "$FAKE_DL_CTL/seconds" 2>/dev/null || echo 600)
case $mode in
  slowtar) [[ $url == *.tar.gz ]] && sleep "$secs" ;;
  fail22) exit 22 ;;
  netfail) exit 7 ;;
esac
cp -- "${url#file://}" "$out" || exit 37
printf "https://bioconductor.org/packages/3.23/data/annotation/src/contrib/%s" "$(basename "$url")"
'

# World: <root>/annotation/<leaf> (0755, owned by the test user), repository, fake downloader, allowlist,
# test config. `pkgs` is a character vector of fake package names; species are "sp1", "sp2", ...
apk_world <- function(pkgs = "org.Fake1.eg.db", env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  parent <- file.path(root, "annotation")
  dir.create(parent, mode = "0755")
  Sys.chmod(parent, "0755")
  lib <- file.path(parent, richStudio:::annotation_lib_leaf())
  dir.create(lib, mode = "0755")
  Sys.chmod(lib, "0755")
  contrib <- file.path(root, "repo", "src", "contrib")
  dir.create(contrib, recursive = TRUE)
  index <- character()
  for (p in pkgs) {
    src <- file.path(root, "src", p)
    dir.create(file.path(src, "R"), recursive = TRUE)
    writeLines(c(paste0("Package: ", p), "Version: 1.0.0", "Title: Tiny fake annotation package",
                 "Description: Tiny fake annotation package used only by installer tests.",
                 "License: GPL-2", "Encoding: UTF-8"), file.path(src, "DESCRIPTION"))
    writeLines("export(probe_ok)", file.path(src, "NAMESPACE"))
    writeLines("probe_ok <- function() TRUE", file.path(src, "R", "probe.R"))
    tar <- file.path(contrib, paste0(p, "_1.0.0.tar.gz"))
    system2("tar", c("-czf", shQuote(tar), "-C", shQuote(file.path(root, "src")), shQuote(p)))
    index <- c(index, paste0("Package: ", p), "Version: 1.0.0", paste0("MD5sum: ", unname(tools::md5sum(tar))), "")
  }
  writeLines(index, file.path(contrib, "PACKAGES"))
  ctl <- file.path(root, "ctl")
  dir.create(ctl)
  dl_log <- file.path(root, "dl.log")
  file.create(dl_log)
  downloader <- file.path(root, "fake-downloader.sh")
  writeLines(apk_fake_downloader, downloader)
  Sys.chmod(downloader, "0755")
  allow <- file.path(root, "allowlist.tsv")
  rows <- c("species\tpackage\tkind\tstatus\tpreinstall\test_mb\tinst_mb\treactome_supported\treason",
            vapply(seq_along(pkgs), function(i) paste(c(paste0("sp", i), pkgs[[i]], "organism", "available", "no", "1", "1", "yes", ""), collapse = "\t"), ""),
            "*\treactome.db\treactome\tavailable\tno\t1\t1\tn/a\t")
  writeLines(rows, allow)
  cfg <- file.path(root, "test.cfg")
  writeLines(c(paste0("repo: file://", file.path(root, "repo")), paste0("allowlist: ", allow),
               paste0("downloader: ", downloader), "probe: stub"), cfg)
  list(root = root, parent = parent, lib = lib, allowlist = allow, cfg = cfg, ctl = ctl, dl_log = dl_log,
       downloads = function() { x <- readLines(dl_log, warn = FALSE); x[nzchar(x)] },
       status = function() richStudio:::annotation_read_status(lib))
}

# Environment for the real installer, with the test-only seams on (the app forwards both variables).
apk_use_world <- function(w, env = parent.frame()) {
  withr::local_envvar(RICHSTUDIO_ANNOTATION_LIB = w$lib, RICHSTUDIO_ANNOTATION_TEST_MODE = "1",
                      RICHSTUDIO_ANNOTATION_TEST_CONFIG = w$cfg, FAKE_DL_LOG = w$dl_log, FAKE_DL_CTL = w$ctl,
                      .local_envir = env)
  testthat::local_mocked_bindings(annotation_allowlist_path = function() w$allowlist, .env = env)
}
