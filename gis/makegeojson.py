import sys
import geopandas as gp

def main():
    shp_to_geojson(
        "shp/HOUSE2021/HOUSE2021_POLY.shp",
        "geojson/house2021.geojson",
        {"REPDISTNUM": "district_num",
         "REP_DIST": "district_display",
         "SHAPE_AREA": "shape_area"},
        number_transform,
    )
    shp_to_geojson(
        "shp/SENATE2021/SENATE2021_POLY.shp",
        "geojson/senate2021.geojson",
        {"SENDISTNUM": "district_num",
         "SEN_DIST": "district_display",
         "SHAPE_AREA": "shape_area"},
        number_transform,
    )
    shp_to_geojson(
        "shp/GOVCOUNCIL2021/GOVCOUNCIL2021_POLY.shp",
        "geojson/govcouncil2021.geojson",
        {"DIST_NUM": "district_num",
         "DIST_NAME": "district",
         "SHAPE_AREA": "shape_area"},
        word_transform,
    )
    shp_to_geojson(
        "shp/CONGRESSMA118/CONGRESSMA118_POLY.shp",
        "geojson/congressma118.geojson",
        {"DIST_NUM": "district_num",
         "DISTRICT": "district_display",
         "SHAPE_AREA": "shape_area"},
        number_transform,
    )

def shp_to_geojson(in_file, out_file, col_rename, name_transform):
    print(f"Reading {in_file}...")
    geom = (
        gp.read_file(in_file)
        .rename(columns=col_rename)
        .pipe(name_transform)
        .sort_values("district_num")
        [["district",
          "district_display",
          "district_num",
          "shape_area",
          "geometry"]])
    print(f"Write {len(geom)} rows to {out_file}...")
    geom.to_file(out_file)

def number_transform(df):
    new_df = df.assign(
        district = lambda x: (x["district_display"]
                              .map(number_to_word))
    )
    return new_df

def word_transform(df):
    new_df = df.assign(
        district_display = lambda x: (x["district"]
                                      .map(word_to_number))
    )
    return new_df

WORD_TO_NUMBER = {
    'First': '1st',
    'Second': '2nd',
    'Third': '3rd',
    'Fourth': '4th',
    'Fifth': '5th',
    'Sixth': '6th',
    'Seventh': '7th',
    'Eighth': '8th',
    'Ninth': '9th',
    'Tenth': '10th',
    'Eleventh': '11th',
    'Twelfth': '12th',
    'Thirteenth': '13th',
    'Fourteenth': '14th',
    'Fifteenth': '15th',
    'Sixteenth': '16th',
    'Seventeenth': '17th',
    'Eighteenth': '18th',
    'Nineteenth': '19th',
    'Twentieth': '20th',
    'Twenty-First': '21st',
    'Twenty-Second': '22nd',
    'Twenty-Third': '23rd',
    'Twenty-Fourth': '24th',
    'Twenty-Fifth': '25th',
    'Twenty-Sixth': '26th',
    'Twenty-Seventh': '27th',
    'Twenty-Eighth': '28th',
    'Twenty-Ninth': '29th',
    'Thirtieth': '30th',
    'Thirty-First': '31st',
    'Thirty-Second': '32nd',
    'Thirty-Third': '33rd',
    'Thirty-Fourth': '34th',
    'Thirty-Fifth': '35th',
    'Thirty-Sixth': '36th',
    'Thirty-Seventh': '37th',
}

NUMBER_TO_WORD = {
    WORD_TO_NUMBER[word]: word for word in WORD_TO_NUMBER
}

def word_to_number(name):
    """Convert the first word of a legislative distrct like
    'First Middlesex' to '1st Middlesex."""
    parts = name.split(" ")
    word = parts[0]
    if word in WORD_TO_NUMBER:
        parts[0] = WORD_TO_NUMBER[word]
        name = " ".join(parts)
    return name

def number_to_word(name):
    """Convert the first word of a legislative distrct like
    '1st Middlesex' to 'First Middlesex."""
    parts = name.split(" ")
    num = parts[0]
    if num in NUMBER_TO_WORD:
        parts[0] = NUMBER_TO_WORD[num]
        name = " ".join(parts)
    return name
            
if __name__ == "__main__":
    main()
