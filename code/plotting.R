library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(ggplot2)

### --- 1. DOWNLOAD DATA (5 YEARS) ---
base_url = "https://archive-api.open-meteo.com/v1/archive"
params <- list(
  latitude = 52.52,
  longitude = 13.41,
  start_date = "2019-01-01",
  end_date   = "2025-11-08",
  hourly = "precipitation",
  timezone = "UTC"
)

res <- GET(base_url, query = params)
raw <- content(res, as = "text")
dat <- fromJSON(raw)
dat_hourly <- data.frame(dat$hourly)


# Expect dat to contain at least: date, value
weather <- dat_hourly %>%
  mutate(date = as.Date(time),
         year = year(time),
         month = month(time, label = TRUE),
         day_of_year = yday(time),
         hour_of_day = hour(ymd_hm(time))
         )

# Filter only relevant hours for calculation
weather_filt <- weather %>%
  filter(hour_of_day >= 8, hour_of_day <= 22)

### --- 2. MONTHLY MEAN & SD (long-term) ---
# only use past years for calculations
current_year <- max(weather_filt$year)
stats_monthly <- weather_filt %>%
  filter(year != current_year) %>%
  group_by(month) %>%
  summarise(
    mean_val = mean(precipitation, na.rm = TRUE),
    sd_val   = sd(precipitation, na.rm = TRUE)
  )

### --- 3. PLOTS FOR CURRENT YEAR ---
weather_curr <- weather_filt %>% 
  filter(year == current_year) %>%
  group_by(day_of_year, month) %>%
  summarise(
    mean_val_d = mean(precipitation, na.rm = TRUE)
  )


# Merge long-term stats
weather_plot <- weather_curr %>%
  left_join(stats_monthly, by = "month") %>%
  mutate(
    upper_2sd = mean_val + 2 * sd_val,
    flag_red = mean_val_d > upper_2sd
  )

# Create one plot per month
months_list <- unique(weather_plot$month)


for(m in months_list){
  
  hist(weather_filt %>%
         filter(month == m) %>%
         pull(precipitation),
       xlab = "precipitation",
       ylab = "density",
       main = paste0(m))
}

for(m in months_list){
  df <- weather_filt %>%
    filter(month == m)
  p <- ggplot(df, aes(x = precipitation)) +
    geom_histogram(aes(y = ..density..), bins = 30) +
    labs(
      title = m,
      x = "precipitation",
      y = "density"
    ) +
    theme_minimal()
  ggsave(paste0("monthly_hist/hist_", "_", m, ".png"), p, width = 7, height = 4)
}

for(m in months_list) {
  print(m)
  df <- weather_plot %>% filter(month == m)
  
  p <- ggplot(df, aes(x = day_of_year, y = mean_val_d)) +
    geom_line(color = "black") +
    geom_point(aes(color = flag_red)) +
    scale_color_manual(values = c("FALSE" = "black", "TRUE" = "red")) +
    geom_hline(aes(yintercept = mean_val), linetype = "solid") +
    geom_hline(aes(yintercept = mean_val + sd_val), linetype = "dashed") +
    geom_hline(aes(yintercept = mean_val + 2*sd_val), linetype = "dotted") +
    labs(
      title = paste("Weather in", m, current_year),
      x = "Day of Year",
      y = "precipitation"
    ) +
    theme_minimal()
  
  ggsave(paste0("monthly/weather_", current_year, "_", m, ".png"), p, width = 7, height = 4)
}
