# frozen_string_literal: true

##
# Represents a file download for a day
# @note: While some attributes could be derived, they are stored in the database to avoid the need to recalculate them
#
# == Attributes
#
# * +ip_address+ - The IP address of the browser client that downloaded the file
# * +web_file_id+ - The web_id of the datafile that was downloaded
# * +download_date+ - The date the file was downloaded
# * +filename+ - The name of the file that was downloaded
# * +dataset_key+ - The dataset key of the file that was downloaded
# * +doi+ - The DOI of the file that was downloaded

class DayFileDownload < ApplicationRecord
end
