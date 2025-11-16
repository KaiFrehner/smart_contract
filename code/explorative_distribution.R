library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(fitdistrplus) 


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

### how does the distribution of the hourly weather data look?
x <- weather_filt %>%
  filter(month == "Mar") %>%
  pull(precipitation)

hist(x, freq = F)
abline(v=
         qlnorm(p = 0.975, 
                meanlog = stats_monthly[stats_monthly$month=="Mar",]$mean_val,
                sdlog =stats_monthly[stats_monthly$month=="Mar",]$sd_val)
)
abline(v=
         qlnorm(p = 0.85, 
                meanlog = stats_monthly[stats_monthly$month=="Mar",]$mean_val,
                sdlog =stats_monthly[stats_monthly$month=="Mar",]$sd_val)
)

lines(seq(0,5,0.01), 
      dlnorm(x = seq(0,5,0.01), 
             meanlog = stats_monthly[stats_monthly$month=="Mar",]$mean_val,
             sdlog =stats_monthly[stats_monthly$month=="Mar",]$sd_val)
)


# try and fit some data
fit_pois <- fitdistr(x, "poisson")
summary(fit_pois)
hist(x, freq=F)
lines(seq(0,5,0.1), dpois(seq(0,5,0.1), lambda = fit_pois$estimate))

fit_exp <- fitdistr(data=c(0.1,0.1,0.1,0.1,0.1,rep(0.4,7)), distr="normal")

(missing(x) || length(x) == 0L || mode(x) != "numeric")
  
str(x[0])
summary(fit_nbin)
plot(fit_nbin)
descdist(x)
sum(weather_filt %>%
      filter(month == "Mar") %>%
      pull(precipitation) > qlnorm(p = 0.85, 
                                   meanlog = (stats_monthly[stats_monthly$month=="Mar",]$mean_val),
                                   sdlog =(stats_monthly[stats_monthly$month=="Mar",]$sd_val))) /
  length(weather_filt %>%
           filter(month == "Mar") %>%
           pull(precipitation))

library(tweedie)
?tweedie
rtweedie(100, xi = 1, mu = 0.1, phi = 1, power = 1)
dtweedie_wrapper <- function(x, xi, mu, phi, p) {
  dtweedie(x, xi = xi, mu = mu, phi = phi, power = p)
}
p_fixed <- 1.5  # must be fixed

fit <- fitdistr(
  x,
  densfun = dtweedie_wrapper,
  start = list(mu = mean(x), xi = 1.5, phi = 1),
  p = p_fixed
)

fit
