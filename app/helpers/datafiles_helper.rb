module DatafilesHelper
  module_function

  def text_preview(datafile)
    datafile.with_input_io do |io|
      io.readline(nil, 500)
    end
  end

  def full_text(datafile)
    datafile.with_input_io do |io|
      io.readline(nil, 5000)
    end
  end
end
