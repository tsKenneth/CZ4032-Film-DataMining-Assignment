# Initialise Libraries for data cleaning ======================================

library(plyr)
library(dplyr)
library(tidytext)
library(stringr)
library(caTools)

# Initialise Variables and environment =======================================
setwd("C:/Users/sogge/Desktop/GitRepos/CZ4032-Film-DataMining-Assignment/Dataset")

df.raw <- read.csv("movie_metadata.csv")
set.seed(1337)

# DEBUG: Shrink dataset size to decrease development time
#sample = sample.split(df.raw$movie_title, SplitRatio = .10)
#df.raw = subset(df.raw, sample == TRUE)

# [Section 1] Genre Cleaning ==================================================

df.genres <- subset(df.raw, select = c(genres, plot_keywords))

# Splitting the movie genres
df.genres$genres <- as.character(df.genres$genres)
df.genres$genres <- strsplit(df.genres$genres, "|", fixed = T)

# Get a vector of unique genres
genres <- unlist(as.vector(df.genres$genres))
genres <- unique(genres)

# 26 unique genres
length(genres)

# Remove certain genres that are irrelevant to movies
genresToRemove <- c('Game-Show','Reality-TV','News')
genres <- genres[!(genres %in% genresToRemove)]

# Splitting the plot keywords, delimited by the pipe symbol |
df.genres$plotKeywords <- as.character(df.genres$plot_keywords)
df.genres$plotKeywords <- strsplit(df.genres$plotKeywords,"|", fixed = T)
keywords <- as.vector(df.genres$plotKeywords)

# 4761 unique keywords
length(unique(keywords))

genreKeys <- data.frame(genres)
genreKeys$keywords <- NA

# Scan through all keywords and assign the keyword to the genre if it is found in the movie with the genre specified
for(i in 1:nrow(df.genres)){
  for(j in 1:nrow(genreKeys)){
    if(grepl(genreKeys$genres[j],df.genres$genres[i])){
      if(is.na(genreKeys$keywords[j])){
        genreKeys$keywords[j]<- c(df.genres$plotKeywords[i])
      }
      else
        genreKeys$keywords[[j]] <- c(genreKeys$keywords[[j]],df.genres$plotKeywords[[i]], recursive =T)
    }
  }
}

# [Section 2] Assigning weights to keywords ==================================================
# Keep only the unique keywords

keywordWeights <- data.frame(keywords = genreKeys$genres)
for (i in 1:nrow(genreKeys)) {
  genreKeys$keywords[[i]] <- unique(genreKeys$keywords[[i]])
  words <- unlist(genreKeys$keywords[[i]])
  keywordWeights$wordList[[i]] <- data.frame(words, 1)
  colnames(keywordWeights$wordList[[i]]) <- c("words",paste("is",keywordWeights$keywords[[i]],sep=""))

  for (j in 1:nrow(keywordWeights$wordList[[i]])) {
    countWord <- length(grep(keywordWeights$wordList[[i]]$words[j],genreKeys$keywords[[i]]))
    keywordWeights$wordList[[i]]$wordCount[j] <- countWord
    keywordWeights$wordList[[i]]$weight[j] <- keywordWeights$wordList[[i]]$wordCount[j]/sum(keywordWeights$wordList[[i]]$wordCount)
  }
  colnames(keywordWeights$wordList[[i]])[4]<- paste(keywordWeights$keywords[[i]],"Weight",sep="")
}

# Joining all by key weight
df.keyWeight <- join_all(keywordWeights$wordList, by = "words", type = "full")
df.keyWeight <- subset(df.keyWeight, select = -c(wordCount,grep("^is",colnames(df.keyWeight))))

# Converting all NA to 0
df.keyWeight[is.na(df.keyWeight)] <- 0

# Joining all by key count
df.keyCount <- join_all(keywordWeights$wordList, by = "words", type = "full")
df.keyCount <- subset(df.keyCount, select = -c(wordCount,grep("Weight$",colnames(df.keyCount))))

# Converting all NA to 0
df.keyCount[is.na(df.keyCount)] <- 0

# [Section 3A] Calculating sum of weights to determine dominant genre ========================
df.movieWeight <- df.raw

# Removing unnecessary data
df.movieWeight <- subset(df.movieWeight, !is.na(gross))
df.movieWeight <- subset(df.movieWeight, !is.na(duration))
df.movieWeight <- subset(df.movieWeight, !is.na(budget))
df.movieWeight <- subset(df.movieWeight, title_year >= 2000)
df.movieWeight <- df.movieWeight[!duplicated(df.movieWeight$movie_title),]
df.movieWeight <- subset(df.movieWeight, select = c(plot_keywords, movie_title))

# Separating plot keywords into a list
df.movieWeight$plot_keywords <- as.character(df.movieWeight$plot_keywords)
df.movieWeight$plot_keywords <- strsplit(df.movieWeight$plot_keywords,"|", fixed = T)

# Initialising the weight columns for df.movieWeight
df.movieWeight[,colnames(df.keyWeight)] <- 0

# Changing words from factor to character
df.keyWeight$words <- as.character(df.keyWeight$words)

# Sum weights for each movie based on keywords
for (i in 1:nrow(df.movieWeight)){
  if(lengths(df.movieWeight$plot_keywords[i]) == 0){
    next
  }
  for (j in 1:lengths(df.movieWeight$plot_keywords[i])) {
    for(k in 1:nrow(df.keyWeight)){
      if(df.movieWeight$plot_keywords[[i]][j] == df.keyWeight[k,1]){
        for(l in 1:(length(df.movieWeight)-3)){
          df.movieWeight[i,(l+3)] <- df.movieWeight[i,(l+3)] + df.keyWeight[k,(l+1)]
        }
        break
      }
    }
  }
}

# Choosing the highest weight column as the dominant genre
df.movieWeight.num <- subset(df.movieWeight, select = -c(plot_keywords, movie_title,words))
df.movieWeight$dominantGenre <- colnames(df.movieWeight.num)[apply(df.movieWeight.num,1,which.max)]

# [Section 3B] Calculating word count to determine dominant genre ========================
df.movieCount <- df.raw

#Removing unnecessary data
df.movieCount <- subset(df.movieCount, !is.na(gross))
df.movieCount <- subset(df.movieCount, !is.na(duration))
df.movieCount <- subset(df.movieCount, !is.na(budget))
df.movieCount <- subset(df.movieCount, title_year >= 2000)
df.movieCount <- df.movieCount[!duplicated(df.movieCount$movie_title),]
df.movieCount <- subset(df.movieCount, select = c(plot_keywords, movie_title))

# Separating plot keywords into a list
df.movieCount$plot_keywords <- as.character(df.movieCount$plot_keywords)
df.movieCount$plot_keywords <- strsplit(df.movieCount$plot_keywords,"|", fixed = T)

# Initialising the weight columns for df.movieWeight
df.movieCount[,colnames(df.keyCount)] <- 0
# Changing words from factor to character
df.keyCount$words <- as.character(df.keyCount$words)

# Sum count for each movie based on keywords
for (i in 1:nrow(df.movieCount)){
  if(lengths(df.movieCount$plot_keywords[i]) == 0){
    next
  }
  for (j in 1:lengths(df.movieCount$plot_keywords[i])) {
    for(k in 1:nrow(df.keyCount)){
      if(df.movieCount$plot_keywords[[i]][j] == df.keyCount[k,1]){
        for(l in 1:(length(df.movieCount)-3)){
          df.movieCount[i,(l+3)] <- df.movieCount[i,(l+3)] + df.keyCount[k,(l+1)]
        }
        break
      }
    }
  }
}

# Choosing the highest count column as the dominant genre
df.movieCount.num <- subset(df.movieCount, select = -c(plot_keywords, movie_title,words))
df.movieCount$dominantGenre <- colnames(df.movieCount.num)[max.col(df.movieCount.num,ties.method = "random")]

# [Section 4] Assigning Dominant Genre ========================

# For Weight
df.movieWeightClassified <- df.movieWeight
df.movieWeightClassified$dominantGenre <- gsub("Weight","",df.movieWeightClassified$dominantGenre)

# For Count
df.movieCountClassified <- df.movieCount
df.movieCountClassified$dominantGenre <- gsub("is","",df.movieCountClassified$dominantGenre)

summary(factor(df.movieWeightClassified$dominantGenre))
summary(factor(df.movieCountClassified$dominantGenre))

# [Section 5] Removing irrelevant records ========================

df.final <- df.raw

# Remove data without gross 
df.final <- subset(df.final, !is.na(gross))
# Remove data without duration
df.final <- subset(df.final, !is.na(duration))
# Remove data without budget
df.final <- subset(df.final, !is.na(budget))
# Subsetting only recent movies (Title year >= 2000 only)
df.final <- subset(df.final, title_year >= 2000)

# Remove duplicated movies
df.final <- df.final[!duplicated(df.final$movie_title),]


# Choosing the highest facebook likes for the three actors
df.final$actor_fb_likes <- pmax(df.final$actor_1_facebook_likes, df.final$actor_2_facebook_likes,
                                df.final$actor_3_facebook_likes, na.rm = T)

# Converting unavailable information to NA
df.final$color[df.final$color == ""] <- NA  
df.final$director_name[df.final$director_name == ""] <- NA
df.final$actor_3_name[df.final$actor_3_name == ""] <- NA
df.final$content_rating[df.final$content_rating == ""] <- NA


# Eliminating irrelevant columns
df.final <- subset(df.final, select = -c(title_year, language, content_rating, country,
                               actor_3_name, actor_1_name, actor_2_name,
                               director_name, actor_2_facebook_likes, 
                               actor_3_facebook_likes, actor_1_facebook_likes, num_critic_for_reviews,
                               num_user_for_reviews, num_voted_users, color, movie_imdb_link, aspect_ratio))

# Merging with dominant genre
df.finalMerged <- join_all(list(df.final, df.movieCountClassified), by = "movie_title", type = "left")
df.finalMerged <- subset(df.finalMerged, select = c(gross, duration, budget,imdb_score ,dominantGenre,
                                          director_facebook_likes,cast_total_facebook_likes, 
                                          facenumber_in_poster, movie_facebook_likes, actor_fb_likes))

#Converting NA's to Mean
df.finalMerged$facenumber_in_poster[is.na(df.finalMerged$facenumber_in_poster)] <- mean(df.finalMerged$facenumber_in_poster, na.rm = T)
df.finalMerged$actor_fb_likes[is.na(df.finalMerged$actor_fb_likes)] <- mean(df.finalMerged$actor_fb_likes, na.rm = T)


summary(df.finalMerged)

write.csv(df.finalMerged, file = "movies_cleaned.csv")
