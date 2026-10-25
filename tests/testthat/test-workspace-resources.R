test_that("installed policy is complete and boundary admission fails closed", {
  policy <- richStudio:::workspace_resource_policy()
  expect_identical(policy$schema_version, 1L)
  expect_true(all(vapply(policy$limits, function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0, logical(1))))
  expect_silent(richStudio:::workspace_check_resources(policy$limits, policy))
  for (key in names(policy$limits)) {
    metrics <- setNames(list(policy$limits[[key]] + 1), key)
    expect_error(richStudio:::workspace_check_resources(metrics, policy), key, fixed = TRUE)
  }
  expect_error(richStudio:::workspace_check_resources(list(unknown = 1), policy), "Unknown")
  for (value in list(NA_real_, Inf, -1, "1", numeric())) {
    expect_error(richStudio:::workspace_check_resources(list(rows = value), policy), "Invalid")
  }
})

test_that("missing malformed and incomplete resource policies cannot admit work", {
  expect_error(richStudio:::workspace_resource_policy(tempfile()), "unavailable")
  file <- tempfile(fileext = ".json")
  on.exit(unlink(file), add = TRUE)
  for (text in c("{", "{}", '{"schema_version":2,"limits":{}}', '{"schema_version":1,"limits":{"rows":1}}')) {
    writeLines(text, file)
    expect_error(richStudio:::workspace_resource_policy(file))
  }
  valid <- richStudio:::workspace_resource_policy()
  for (value in list(0, -1, Inf, NA_real_, "100", list(1, 2))) {
    invalid <- valid
    invalid$limits$rows <- value
    jsonlite::write_json(invalid, file, auto_unbox = TRUE, na = "null")
    expect_error(richStudio:::workspace_resource_policy(file))
    expect_error(richStudio:::workspace_check_resources(list(rows = 1), invalid))
  }
})

test_that("job queue limits come from the installed resource policy", {
  policy <- richStudio:::workspace_resource_policy()
  expect_identical(policy$limits$job_queue_process, 8L)
  expect_identical(policy$limits$job_queue_session, 1L)
  expect_identical(richStudio:::workspace_job_queue_limit(), 8L)
  expect_identical(richStudio:::workspace_job_session_queue_limit(), 1L)
  changed <- policy
  changed$limits$job_queue_process <- 3L
  changed$limits$job_queue_session <- 2L
  testthat::local_mocked_bindings(workspace_resource_policy = function(...) changed, .package = "richStudio")
  expect_identical(richStudio:::workspace_job_queue_limit(), 3L)
  expect_identical(richStudio:::workspace_job_session_queue_limit(), 2L)
})
