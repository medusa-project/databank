# frozen_string_literal: true

##
# Represents the ingest responses
# Ingest responses are the responses from Medusa Collection Registry
#
# == Attributes
#
# * +as_text+ - (String) - response as text
# * +status+ - (String) - status of the response, e.g. "200 OK"
# * +response_time+ - (String) - time the response was received
# * +staging_key+ - (String) - storage key in the staging/draft root
# * +medusa_key+ - (String) - storage key in Medusa root
# * +uuid+ - (String) - UUID of the object in the Medusa Collection Registry

class IngestResponse < ApplicationRecord
end
