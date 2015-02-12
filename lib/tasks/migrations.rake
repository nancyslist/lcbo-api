namespace :migrations do
  desc 'Normalize producer information'
  task associate_producers: :environment do
    puts 'Creating producers and associating products...'
    Product.where(producer_id: nil).find_each do |product|
      product.associate_producer!
      STDOUT.print '.'
      STDOUT.flush
    end
    puts
    puts '> Done'
  end

  desc 'Identify Ontario Craft Brewers'
  task identify_ocb_producers: :environment do
    puts 'Finding OCB producers...'

    producers = LCBO::OCBProducersCrawler.parse[:producers]
    ocb_names = Hash[producers.map { |p| [p[:normalized_name], p[:name]] }]

    Producer.where(is_ocb: false).find_each do |producer|
      found_name = nil
      lcbo_norm  = LCBO::OCBProducersCrawler.normalize_name(producer.name)

      ocb_names.each_pair do |ocb_norm, ocb_name|
        next unless lcbo_norm.starts_with?(ocb_norm)
        found_name = ocb_name
        break
      end

      next unless found_name

      producer.update(
        is_ocb: true,
        name: found_name
      )

      STDOUT.print('.')
      STDOUT.flush
    end

    puts
    puts '> Done'
  end

  desc 'Normalize producer information and identify Ontario Craft Brewers'
  task normalize_producers: [:associate_producers, :identify_ocb_producers]

  desc 'Clean product categories'
  task clean_product_categories: :environment do
    puts "Cleaning product categories..."

    Product.where(%{
      (primary_category LIKE '%Price $ %') OR
      (primary_category LIKE '%CLEARANCE%') OR
      (primary_category = 'N/A') OR
      (primary_category = '')
    }).update_all(primary_category: nil)

    Product.where(%{
      (primary_category = 'Ready-To-') OR
      (primary_category = 'Ready-To-Drink/Coolers') OR
      (primary_category = 'Coolers and Cocktails')
    }).update_all(primary_category: 'Ready-to-Drink/Coolers')

    Product.where(%{
      (primary_category = 'Non-Alcoholic') OR
      (primary_category = 'Non-Alc')
    }).update_all(primary_category: 'Accessories and Non-Alcohol Items')

    puts "> Done"
  end

  desc 'Normalize category information'
  task normalize_categories: [:environment, :clean_product_categories] do
    puts 'Normalizing categories...'

    Product.find_each do |product|
      product.associate_categories!
      STDOUT.print('.')
      STDOUT.flush
    end

    puts
    puts '> Done'
  end

  desc 'Normalize all data in the system'
  task normalize: [:normalize_producers, :normalize_categories]
end