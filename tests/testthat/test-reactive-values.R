# Test Reactive Value Handling
#
# These tests ensure that reactive values are properly updated
# without using the <<- anti-pattern.
#
# @author richStudio Development Team

# Load required packages
library(shiny)

test_that("reactiveValues properly handle single assignment pattern", {
  # Test that the correct pattern (local modification + single assignment) works

  # Create mock reactive values
  rv <- reactiveValues(df = data.frame(x = 1:5, y = letters[1:5]))

  # Simulate DataTable edit event - use correct pattern
  i <- 2
  j <- 1
  v <- "updated"

  # Correct pattern: Modify locally, then assign once
  updated_df <- isolate(rv$df)
  updated_df[i, j] <- v
  rv$df <- updated_df

  # Verify the update worked
  expect_equal(isolate(rv$df)[2, 1], "updated")
  # Note: assigning a character to an integer column coerces entire column to character
  expect_equal(isolate(rv$df)[1, 1], "1")  # Other rows unchanged (coerced to character)
})

test_that("reactiveValues properly handle multiple sequential edits", {
  # Test multiple sequential edits to same reactive value

  rv <- reactiveValues(df = data.frame(
    name = c("A", "B", "C"),
    value = c(1, 2, 3)
  ))

  # First edit
  updated_df <- isolate(rv$df)
  updated_df[1, 2] <- 10
  rv$df <- updated_df

  # Second edit
  updated_df <- isolate(rv$df)
  updated_df[2, 2] <- 20
  rv$df <- updated_df

  # Third edit
  updated_df <- isolate(rv$df)
  updated_df[3, 2] <- 30
  rv$df <- updated_df

  # Verify all edits persisted
  expect_equal(isolate(rv$df)$value, c(10, 20, 30))
})

test_that("reactiveValues properly handle rename operations", {
  # Test the pattern used for renaming entries

  rv_names <- reactiveValues(labels = c("file1", "file2", "file3"))
  rv_data <- reactiveValues()
  rv_data[["file1"]] <- data.frame(x = 1:5)
  rv_data[["file2"]] <- data.frame(x = 6:10)
  rv_data[["file3"]] <- data.frame(x = 11:15)

  # Rename file1 to new_file1
  old_name <- "file1"
  new_name <- "new_file1"

  # Copy data to new name
  rv_data[[new_name]] <- isolate(rv_data[[old_name]])
  # Remove old name
  rv_data[[old_name]] <- NULL
  # Update labels
  rv_names$labels <- setdiff(isolate(rv_names$labels), old_name)
  rv_names$labels <- c(isolate(rv_names$labels), new_name)

  # Verify rename worked
  expect_null(isolate(rv_data[["file1"]]))
  expect_true(is.data.frame(isolate(rv_data[["new_file1"]])))
  expect_false("file1" %in% isolate(rv_names$labels))
  expect_true("new_file1" %in% isolate(rv_names$labels))
})

test_that("reactiveValues properly handle remove operations", {
  # Test the pattern used for removing entries

  rv_names <- reactiveValues(labels = c("file1", "file2", "file3"))
  rv_data <- reactiveValues()
  rv_data[["file1"]] <- data.frame(x = 1:5)
  rv_data[["file2"]] <- data.frame(x = 6:10)
  rv_data[["file3"]] <- data.frame(x = 11:15)

  # Remove file1 and file3
  to_remove <- c("file1", "file3")
  for (name in to_remove) {
    rv_data[[name]] <- NULL
  }
  rv_names$labels <- setdiff(isolate(rv_names$labels), to_remove)

  # Verify removals worked
  expect_null(isolate(rv_data[["file1"]]))
  expect_true(is.data.frame(isolate(rv_data[["file2"]])))
  expect_null(isolate(rv_data[["file3"]]))
  expect_equal(isolate(rv_names$labels), "file2")
})

test_that("reactiveValues handle DT::coerceValue correctly", {
  # Test that DT::coerceValue works with the new pattern

  rv <- reactiveValues(df = data.frame(
    name = c("A", "B"),
    value = c(1, 2)
  ))

  # Simulate DataTable cell edit with type coercion
  i <- 1
  j <- 2
  v <- "10"  # String that should be coerced to numeric

  updated_df <- isolate(rv$df)
  updated_df[i, j] <- DT::coerceValue(v, updated_df[i, j])
  rv$df <- updated_df

  # Verify coercion worked
  expect_equal(isolate(rv$df)[1, 2], 10)
  expect_type(isolate(rv$df)[1, 2], "double")
})

test_that("reactiveValues maintain data integrity after edits", {
  # Test that data frame structure is maintained

  rv <- reactiveValues(df = data.frame(
    id = 1:5,
    category = c("A", "B", "A", "B", "A"),
    value = rnorm(5)
  ))

  original_ncol <- ncol(isolate(rv$df))
  original_nrow <- nrow(isolate(rv$df))

  # Perform edit
  updated_df <- isolate(rv$df)
  updated_df[3, 3] <- 999
  rv$df <- updated_df

  # Verify structure maintained
  expect_equal(ncol(isolate(rv$df)), original_ncol)
  expect_equal(nrow(isolate(rv$df)), original_nrow)
  expect_equal(names(isolate(rv$df)), names(data.frame(id = 1, category = "A", value = 1)))
})

test_that("reactiveValues handle edge cases correctly", {
  # Test edge cases: empty data frames, single row, etc.

  # Empty data frame
  rv_empty <- reactiveValues(df = data.frame())
  updated_df <- isolate(rv_empty$df)
  # Attempt to edit empty frame should not crash
  expect_true(nrow(updated_df) == 0)

  # Single row data frame
  rv_single <- reactiveValues(df = data.frame(x = 1))
  updated_df <- isolate(rv_single$df)
  updated_df[1, 1] <- 100
  rv_single$df <- updated_df
  expect_equal(isolate(rv_single$df)[1, 1], 100)

  # Single column data frame
  rv_single_col <- reactiveValues(df = data.frame(x = 1:5))
  updated_df <- isolate(rv_single_col$df)
  updated_df[3, 1] <- 999
  rv_single_col$df <- updated_df
  expect_equal(isolate(rv_single_col$df)[3, 1], 999)
})
