# frozen_string_literal: true

##
# Represents a featured researcher
#
# == Attributes
#
# * +name+ - name of the researcher
# * +question+ - question that the researcher is answering
# * +testimonial+ - testimonial from the researcher, in response to the question
# * +bio+ - bio of the researcher
# * +photo_url+ - url to the photo of the researcher (in Box)
# * +dataset_url+ - url to the dataset that the researcher is associated with
# * +article_url+ - url to the article that the researcher is associated with
# * +is_active+ - whether the researcher is currently featured (feature published)
# * +binary+ - deprecated (was used to store the photo of the researcher using paperclip gem)

class FeaturedResearcher < ApplicationRecord
end
