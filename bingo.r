# bingo
library(tidyverse)
library(furrr)

plan(multisession, workers = 10)

generate_card <- function(size = 5) {
    if (size %% 2 == 0 || size > 7) stop("Cannot use the function. Need odd sizes 7 or below")
    sq_size <- size^2 - 1
    bingo_numbers <- sample(1:75, sq_size, replace = FALSE)
    matrix(c(bingo_numbers[1:(sq_size %/% 2)], 0, bingo_numbers[(1 + sq_size %/% 2):sq_size]), nrow = size)
}

generate_col_card <- function(size = 5) {
    if (size != 5) stop("Size must be 5")
    bingo_numbers <- c(
        sample(1:15, size, replace = FALSE),
        sample(16:30, size, replace = FALSE),
        sample(31:45, size, replace = FALSE),
        sample(45:60, size, replace = FALSE),
        sample(61:75, size, replace = FALSE)
    )

    m <- matrix(bingo_numbers, nrow = size)
    m[1 + size %/% 2, 1 + size %/% 2] <- 0
    m
}


generate_draw <- function(size = 75) {
    sample(1:size, size, replace = FALSE)
}

check_card <- function(bingo_card, size = 5) {
    any(
        c(
            colSums(bingo_card),
            rowSums(bingo_card),
            sum(bingo_card[OBVERSE_DIAG]),
            sum(bingo_card[REVERSE_DIAG])
        ) == 0
    )
}

check_direction <- function(ticked_bingo_card) {
    dplyr::case_when(
        any(colSums(ticked_bingo_card) == 0) ~ "V",
        any(rowSums(ticked_bingo_card) == 0) ~ "H",
        sum(ticked_bingo_card[OBVERSE_DIAG]) == 0 ~ "D1",
        sum(ticked_bingo_card[REVERSE_DIAG]) == 0 ~ "D2",
        TRUE ~ "0"
    )
}

tickoff_card <- function(bingo_card, draw_numbers, size = 5) {
    winning <- FALSE
    i <- 1

    while (!winning) {
        bingo_card[which(bingo_card == draw_numbers[i])] <- 0
        if (sum(bingo_card == 0) >= 4) winning <- check_card(bingo_card, size)
        i <- i + 1
    }

    return(i - 1)
}

tickoff_card_direction <- function(bingo_card, draw_numbers, size = 5) {
    winning <- FALSE
    i <- 1

    while (!winning) {
        bingo_card[which(bingo_card == draw_numbers[i])] <- 0
        winning <- check_card(bingo_card, size)
        i <- i + 1
    }
    check_direction(bingo_card)
}

size <- 5
n_draws <- 1000
n_cards <- 10000

all_cards <- lapply(seq_len(n_cards), \(x) generate_col_card(size = 5))
all_draws <- lapply(seq_len(n_draws), \(x) generate_draw(size = 75))

# pre-compute the diagonal patterns
REVERSE_DIAG <- row(all_cards[[1]]) == size + 1 - col(all_cards[[1]]) # nolint
OBVERSE_DIAG <- row(all_cards[[1]]) == col(all_cards[[1]]) # nolint

all_trials <- future_map(all_draws, \(draw) {
    future_map_dbl(all_cards, \(card) {
        tickoff_card(card, draw)
    })
})

save(all_trials, file = "alltrials.RData")

mins <- map(all_trials, which.min)

min_draws <- map(seq_along(mins), \(n) all_draws[[n]])
min_cards <- map(mins, \(n) all_cards[[n]])

direction <- future_map2_chr(min_cards, min_draws, tickoff_card_direction)
table(direction)
