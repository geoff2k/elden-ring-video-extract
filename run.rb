require 'rtesseract'

VERBOSE = false

VIDEO_URL = "https://www.youtube.com/watch?v=31gqB5eUC94"

REGEX = /Merging formats into \"(.*?)\"/

def download(url, prefix)
  output = ''
  IO.popen("yt-dlp #{"-v" if VERBOSE}  --force-overwrites --no-progress -o #{prefix} #{url}") do |io|
    io.each do |l|
      if o = REGEX.match(l)
        output = o[1]
      end
    end
  end
  output
end

def extract_frames(output_file)
  system "ffmpeg -i #{output_file} '%08d.png'"
end

def frame_count(file)
  count = -1
  IO.popen("ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 #{file}") do |io|
    io.each do |l|
      next if l.strip.length < 1
      count = Integer(l.strip.gsub(",",""))
    end
  end
  count
end

def ocr(frame_file)
  system "convert #{"-verbose" if VERBOSE}  #{frame_file} -crop 1150x45+0+290 single-frame.png"

  box =  RTesseract.new("single-frame.png").to_box

  items = []
  words = []
  added = false

  box.each do |i|
    if i[:x_start] > 600 && !added # look for the break between words to introduce a new line between them
      items << words.join(" "). gsub("&#39;","'").strip
      added = true
      words = []
    end
    words << i[:word]
  end

  items << words.join(" "). gsub("&#39;","'").strip
  items
end

output_file = download(VIDEO_URL, "input-file")

extract_frames(output_file)

output = {}

(1..frame_count(output_file)).each do |index|
  if index % 20 == 0  # only process every 20th frame
    items = ocr("%08d.png" % index) 
    items.each do |item|
      output[item] = 1
    end
  end
end 

output.keys.sort.each do |item|
  puts item
end
