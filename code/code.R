
install.packages("meteo")
install.packages("sf")
install.packages("rnaturalearth")
install.packages("rnaturalearthdata")
library(readr)
library(dplyr)
library(purrr)
library(lubridate)
library(ggplot2)
library(meteo)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)

folder_path <- "/Users/benji/Desktop/weather/ECA_nonblend_rr"
files <- list.files(folder_path, pattern = "RR_SOUID.*\\.txt$", full.names = TRUE)

# select 1000 datsets randomly
set.seed(123)
files_sample <- sample(files, 1000)

#print progress
counter <- 0
total_files <- length(files_sample)

#read and clear data
read_ecad_file_clean <- function(file) {
  
  df <- readr::read_csv(
    file,
    skip = 20,
    col_names = c("STAID","SOUID","DATE","RR","Q_RR"),
    trim_ws = TRUE,
    show_col_types = FALSE
  )
  df <- df %>%
    filter(!is.na(DATE)) %>%
    filter(grepl("^\\d{8}$", DATE)) %>%
    mutate(
      STAID = as.integer(STAID),
      SOUID = as.integer(SOUID),
      DATE = lubridate::ymd(DATE),
      RR = as.numeric(RR),
      Q_RR = as.integer(Q_RR)
    ) %>%
    filter(Q_RR == 0)
  
  counter <<- counter + 1
  if (counter %% 10 == 0 || counter == total_files) {
    cat(sprintf("Datei %d / %d eingelesen: %s\n", counter, total_files, basename(file)))
  }
  
  return(df)
}


#import all cleaned data
all_data_clean <- purrr::map_df(files_sample, read_ecad_file_clean)

#save as csv
write_csv(all_data_clean, "all_precipitation_data_sample_clean.csv")
#convert data
all_data <- read_csv(
  "/Users/benji/Desktop/weather/ECA_nonblend_rr/all_precipitation_data_sample_clean.csv",
  col_types = cols(
    STAID = col_integer(),
    SOUID = col_integer(),
    DATE = col_character(),
    RR = col_double(),
    Q_RR = col_integer()
  )
)

# convert DATES and convert 0.1mm to mm
all_data <- all_data %>%
  mutate(DATE = as.Date(DATE, "%Y-%m-%d")) %>%
  filter(Q_RR == 0) %>%
  mutate(RR = RR /10)  

# save cleaned csv file
write_csv(all_data, "all_precipitation_data_sample_clean.csv")


all_data_clean <- readr::read_csv("all_precipitation_data_sample_clean.csv")
#find rainy days in the dataset (precipitation>=2.9mm) 
all_data_clean <- all_data %>%
  mutate(RR_flag = if_else(RR >= 2.9, 1, 0))

all_data_clean_date <- all_data_clean %>%
  mutate(
    DATE = as.Date(DATE),
    YEAR = year(DATE) 
  )

# sum up number of rainy days as defined before for each year and station
rain_days_per_station_year <- all_data_clean_date %>%
  group_by(STAID, YEAR) %>%
  summarise(
    rain_days = sum(RR_flag, na.rm = TRUE),
    .groups = "drop"
  )

# see output
rain_days_per_station_year
#calculate quantiles to find the risk categories
quantiles <- quantile(rain_days_per_station_year$rain_days, probs = c(0.2, 0.4, 0.6, 0.8))

quantile_text <- paste0(
  "20% Quantile = ", round(quantiles[1], 0), "\n",
  "40% Quantile = ", round(quantiles[2], 0), "\n",
  "60% Quantile = ", round(quantiles[3], 0), "\n",
  "80% Quantile = ", round(quantiles[4], 0)
)

# Plot
ggplot(rain_days_per_station_year, aes(x = rain_days)) +
  geom_histogram(binwidth = 5, fill = "skyblue", color = "black", alpha = 0.7) +
  geom_vline(xintercept = quantiles, color = "red", linetype = "dashed", size = 1) +
  labs(
    title = "Histogram of Rainy Days per Station per Year",
    x = "Number of Rainy Days (Precip ≥ 2.9 mm)",
    y = "Frequency"
  ) +
  annotate("text", x = max(rain_days_per_station_year$rain_days)*0.7, 
           y = max(table(cut(rain_days_per_station_year$rain_days, breaks = 30)))*0.9, 
           label = quantile_text, hjust = 0, vjust = 1, size = 4, color = "black") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.title = element_text(face = "bold")
  )
#in a last step plot the used stations on a map

staid_data <- read_csv("all_precipitation_data_sample_clean.csv")

# extract Station IDs (STAID)
unique_staids <- staid_data %>%
  distinct(STAID) %>%
  rename(unique_STAID = STAID)

# import STAID information (long, lat) from meteo package
data("stations", package = "meteo")

# filter the used STAIDs
stations_sub <- stations %>%
  filter(staid %in% unique_staids$unique_STAID)

# see output
stations_sub

world <- ne_countries(scale = "medium", returnclass = "sf")

# plot the stations on a Europe map
ggplot(data = world) +
  geom_sf(fill = "gray95", color = "black") +
  geom_point(data = stations_sub, aes(x = lon, y = lat),
             color = "blue", size = 2, alpha = 0.7) +
  coord_sf(xlim = c(-25, 50), ylim = c(30, 72)) +  
  labs(title = "Used Weather Stations") +
  theme_minimal(base_size = 14)
