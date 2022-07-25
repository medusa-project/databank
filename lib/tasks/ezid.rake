require 'rake'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'nokogiri/diff'

namespace :ezid do

  desc 'detect and report conflict between IDB and DataCite records'
  task :diff_all => :environment do

    conflict_count = 0

    datacite_report = ""

    existing_idb_record = nil

    Dataset.all.each do |dataset|

      existing_datacite_record = Dataset.datacite_record_hash(dataset)

      uri = URI("#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}.xml")
      req = Net::HTTP::Get.new(uri.path)

      res = Net::HTTP.start(
          uri.host, uri.port,
          :use_ssl => uri.scheme == 'https',
          :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
        https.request(req)
      end

      case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          existing_idb_record = res.body
      end

      has_conflict = nil
      note = "OK"

      case dataset.publication_state

        when Databank::PublicationState::DRAFT
          if existing_datacite_record
            has_conflict = true
            note = "DataCite record exists for draft"
          else
            has_conflict = false
          end

        when Databank::PublicationState::RELEASED
          if existing_datacite_record

            case ((dataset.hold_state.split(" "))[0]).strip
              when "none", "files"
                ezid_doc = existing_datacite_record["metadata"]
                idb_doc = Nokogiri::XML(existing_idb_record)

                doc1 = ezid_doc
                doc2 = idb_doc

                has_conflict = false
                doc1.diff(doc2) do |change,node|
                  if change.length > 1
                    has_conflict = true
                    note = "Difference found in metadata"
                  end
                end
              when "metadata"

                modified_status = ((existing_datacite_record["status"].split(" "))[0]).strip

                case modified_status
                  when "public"
                    has_conflict = true
                    note = "record public for Metadata & File hold"

                  when "reserved"
                    has_conflict = false

                  when "unavailable"

                    ezid_string = existing_datacite_record["metadata"].to_xml
                    if ezid_string.include? "Redacted" and ezid_string.exclude? dataset.title
                      has_conflict = false
                    else
                      has_conflict = true
                      note = "check metadata on EZID for Metadata & File hold"

                    end

                  else
                    has_conflict = true
                    note = "unexpected status: #{existing_datacite_record["status"]}"
                end

              else

                has_conflict = true
                note = "Unexpected hold status for released dataset"

            end

          else
            #puts "inside released with no ezid record"
            has_conflict = true
            note = "no DataCite record found for published dataset"
          end

        when Databank::PublicationState::Embargo::METADATA
          if existing_datacite_record

            modified_status = ((existing_datacite_record["status"].split(" "))[0]).strip

            case modified_status
              when "public"
                has_conflict = true
                note = "record public for Metadata & File embargo"

              when "reserved"
                has_conflict = false

              when "unavailable"
                ezid_string = existing_datacite_record["metadata"].to_xml
                if ezid_string.include? "Redacted" and ezid_string.exclude? dataset.title
                  has_conflict = false
                else
                  has_conflict = true
                  note "check metadata on DataCite for Metadata & File embargo"

                end

              else
                has_conflict = true
                note = "unexpected status: #{existing_datacite_record["status"]}"
            end
          else
            has_conflict = true
            note = "no DataCite record for Embargo dataset"
          end

        when Databank::PublicationState::Embargo::FILE
          if existing_datacite_record
            ezid_doc = existing_datacite_record["metadata"]
            idb_doc = Nokogiri::XML(existing_idb_record)

            doc1 = ezid_doc
            doc2 = idb_doc

            has_conflict = false
            doc1.diff(doc2) do |change,node|
              if change.length > 1
                has_conflict = true
                note = "Difference found in metadata"
              end
            end
          else
            has_conflict = true
            note = "no DataCite record found for File Embargo"
          end

        when Databank::PublicationState::TempSuppress::METADATA
          if existing_datacite_record
            ezid_string = existing_datacite_record["metadata"].to_xml
            if ezid_string.include? "Redacted" and ezid_string.exclude? dataset.title
              has_conflict = false
            else
              has_conflict = true
              note = "check metadata on DataCite for temporary Metadata & File hold"

            end
          else
            has_conflict = false
          end

        when Databank::PublicationState::TempSuppress::FILE
          if existing_datacite_record
            ezid_doc = existing_datacite_record["metadata"]
            idb_doc = Nokogiri::XML(existing_idb_record)

            doc1 = ezid_doc
            doc2 = idb_doc

            has_conflict = false
            doc1.diff(doc2) do |change,node|
              if change.length > 1
                has_conflict = true
                note = "Difference found in metadata"
              end
            end
          else
            has_conflict = true
            note = "missing DataCite record for File Only Embargo"
          end

        when Databank::PublicationState::PermSuppress::METADATA
          if existing_datacite_record
            ezid_string = existing_datacite_record["metadata"].to_xml
            if ezid_string.include? "Redacted" and ezid_string.exclude? dataset.title
              has_conflict = false
            else
              has_conflict = true
              note "check metadata on DataCite for Metadata & File embargo"

            end
          else
            has_conflict = true
            note = "check metadata on DataCite for Metadata & File hold"
          end

        when Databank::PublicationState::PermSuppress::FILE
          if existing_datacite_record
            ezid_doc = existing_datacite_record["metadata"]
            idb_doc = Nokogiri::XML(existing_idb_record)

            doc1 = ezid_doc
            doc2 = idb_doc

            has_conflict = false
            doc1.diff(doc2) do |change,node|
              if change.length > 1
                has_conflict = true
                note = "Difference found in metadata"
              end
            end
          else
            has_conflict = true
            note = "no DataCite record found for permenantly File Only suppressed"
          end

      end

      if has_conflict.nil?
        has_conflict = true
        note = "test incomplete"
      end

      if has_conflict
        conflict_count = conflict_count + 1
        datacite_report << "#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}\t#{note}\n"
      end

    end

    if conflict_count == 0
      datacite_report = "No conflicts were found between Illinois Data Bank and EZID"
    end

    notification = DatabankMailer.ezid_warnings(datacite_report)
    notification.deliver_now

  end

end