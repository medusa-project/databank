require 'csv'
require 'tempfile'

class MetricsController < ApplicationController

  def index
  end

  def dataset_downloads
    @dataset_download_tallies = DatasetDownloadTally.all
  end

  def file_downloads
    @file_download_tallies = FileDownloadTally.all
  end

  def datafiles_simple_list
    datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT).pluck(:id)
    @datafiles = Datafile.where(dataset_id: datasets)
  end

  def datasets_csv

    datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)

    Tempfile.open("datasets_csv") do |t|

      CSV.open(t, 'w') do |report|

        report << ['doi', 'pub_date', 'num_files', 'num_bytes', 'total_downloads', 'num_relationships', 'subject']

        datasets.each do |dataset|

          report << ["#{dataset.identifier}",
                     "#{dataset.release_date.iso8601}",
                     "#{dataset.datafiles.count}",
                     "#{dataset.total_filesize}",
                     "#{dataset.total_downloads}",
                     "#{dataset.num_external_relationships}",
                     "#{dataset.subject}"]

        end

      end

      send_file t.path, :type => 'text/csv',
                :disposition => 'attachment',
                :filename => "datasets.csv"
    end
  end

  def datafiles_csv

    doi_filename_mimetype = MedusaInfo.doi_filename_mimetype

    return nil unless doi_filename_mimetype

    datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)

    Tempfile.open("datafiles_csv") do |t|

      CSV.open(t, 'w') do |report|

        report << ['doi', 'pub_date', 'filename', 'file_format', 'num_bytes', 'total_downloads']

        datasets.each do |dataset|
          dataset.datafiles.each do |datafile|
            doi_filename = "#{dataset.identifier}_#{datafile.bytestream_name }".downcase
            report << ["#{dataset.identifier}",
                       "#{dataset.release_date.iso8601}",
                       "#{datafile.bytestream_name}",
                       "#{doi_filename_mimetype[doi_filename]}",
                       "#{datafile.bytestream_size}",
                       "#{datafile.total_downloads}"]
          end
        end

      end

      send_file t.path, :type => 'text/csv',
                :disposition => 'attachment',
                :filename => "datafiles.csv"
    end

  end

  def funders_csv
    Tempfile.open("funders_csv") do |t|

      datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)

      report = CSV.new(t)

      report << ["doi","funder","grant"]

      datasets.each do |dataset|
        dataset.funders.each do |funder|
          report << [dataset.identifier, funder.name, funder.grant]
        end
      end

      send_file t.path, :type => 'text/csv',
                :disposition => 'attachment',
                :filename => "funders.csv"

      report.close(unlink_now = false)

    end
  end

  def archived_content_csv

    datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)

    Tempfile.open("contained_csv") do |t|

      report = CSV.new(t)

      report << ['doi', 'container_filename', 'content_filepath', 'content_filename', 'file_format']

      datasets.each do |dataset|
        dataset.datafiles.each do |datafile|
          if datafile.archive?
            content_files = datafile.content_files
            content_files.each do |content_hash|

              report << ["#{dataset.identifier}",
                         "#{datafile.bytestream_name}",
                         "#{content_hash['content_filepath']}",
                         "#{content_hash['content_filename']}",
                         "#{content_hash['file_format']}"]
            end
          end
        end
      end

      send_file t.path, :type => 'text/csv',
                :disposition => 'attachment',
                :filename => "contained.csv"

      report.close(unlink_now = false)

    end

  end

  def related_materials_csv

    Tempfile.open("materials_csv") do |t|

      datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)

      report = CSV.new(t)

      report << ["doi,datacite_relationship", "material_id_type", "material_id,material_type"]

      datasets.each do |dataset|
        dataset.related_materials.each do |material|

          datacite_arr = Array.new

          if material.datacite_list && material.datacite_list != ''
            datacite_arr = material.datacite_list.split(',')
            # else
            #   report << ["#{dataset.identifier}", "", "#{material.uri_type}", "#{material.uri}", "#{material.selected_type}"]
          end

          datacite_arr.each do |relationship|

            if ['IsPreviousVersionOf', 'IsNewVersionOf'].exclude?(relationship)
              report << ["#{dataset.identifier}", "#{relationship}", "#{material.uri_type}", "#{material.uri}", "#{material.selected_type}"]
            end

          end
        end
      end

      send_file t.path, :type => 'text/csv',
                :disposition => 'attachment',
                :filename => "related_materials.csv"

      report.close(unlink_now = false)

    end
  end
end