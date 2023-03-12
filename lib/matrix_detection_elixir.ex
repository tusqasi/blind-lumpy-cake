defmodule That do
  @green {0, 255, 0}
  import Bitwise

  def draw_contours_on_image(contours, image) do
    Evision.drawContours(image, contours, -1, @green, thickness: 2)
  end

  def draw_points_on_image(points, image) do
    Enum.reduce(points, image, fn [x, y], img ->
      Evision.circle(img, {x, y}, 1, {0, 255, 0}, thickness: 3)
      |> Evision.putText(
        "#{x}, #{y}",
        {x + 10, y},
        Evision.Constant.cv_FONT_HERSHEY_SIMPLEX(),
        0.5,
        @green
      )
    end)
  end

  @spec filter_by_area(list(), integer(), integer()) :: list()
  def filter_by_area(contours_heirarchy, min_area, max_area) do
    {contours, heirarchy} = contours_heirarchy

    heirarchy = heirarchy |> Evision.Mat.to_nx(Nx.BinaryBackend) |> Nx.to_list() |> List.first()

    {contours, heirarchy} =
      Enum.zip(contours, heirarchy)
      |> Enum.reject(fn {contour, _heirarchy} ->
        area = Evision.contourArea(contour)
        area < min_area or area > max_area
      end)
      |> Enum.unzip()
  end

  def find_quads(contours) do
    Enum.filter(contours, fn c ->
      peri = Evision.arcLength(c, true)
      approx = Evision.approxPolyDP(c, 0.02 * peri, true)
      {_, [size, 1]} = Evision.Mat.size(approx)
      # four sides
      size == 4
    end)
  end

  #                                 next prev fc    parent
  # Find inner most contours        [x   x    -1    x     ]
  # Check if less than 4 contours 
  # Take the parent contour
  # Check if a quad
  # Get the extreme points  
  def find_inner_contours(heirarchy) do
    Enum.filter(
      Enum.with_index(
        heirarchy
        # |> Evision.Mat.to_nx()
        # |> Nx.to_list()
        # |> List.first()
      ),
      fn
        # No children
        {[_, _, -1, _], _} ->
          true

        _ ->
          false
      end
    )
  end

  @spec find_contour_containing_matrix(term) :: [integer()]
  def find_contour_containing_matrix(heirarchy) do
    # Find inner most contours fc == -1
    # Find parents with 4 or less siblings

    inner_contours = That.find_inner_contours(heirarchy)
    # Unique by parent
    Enum.uniq_by(inner_contours, fn {[_, _, _, x], _} -> x end)
    |> Enum.map(fn {[_, _, _, x], _} -> x end)
  end

  def find_extreme_points(contour) do
    peri = Evision.arcLength(contour, true)
    Evision.approxPolyDP(contour, 0.02 * peri, true)
  end

  def crop_to_points(points, image) do
    pts1 = Evision.Mat.literal(points, :f32)

    pts2 =
      Evision.Mat.literal([[10, 10], [400 - 10, 10], [10, 400 - 10], [400 - 10, 400 - 10]], :f32)

    case Evision.getPerspectiveTransform(pts1, pts2) do
      {:ok, m} ->
        Evision.warpPerspective(image, m, {410, 410})

      _ ->
        image
    end
  end


  def test_decode_matrix(image) do
    gray = Evision.cvtColor(image, Evision.Constant.cv_COLOR_BGR2GRAY())

    {_, thresholded} =
      gray
      |> Evision.threshold(
        50,
        255,
        Evision.Constant.cv_THRESH_BINARY() ||| Evision.Constant.cv_THRESH_OTSU()
      )

    {contours, heirarchy} =
      Evision.findContours(
        thresholded,
        Evision.Constant.cv_RETR_TREE(),
        Evision.Constant.cv_CHAIN_APPROX_NONE()
      )
      |> filter_by_area(10000, :infinity)

    contours_with_matrix = find_contour_containing_matrix(heirarchy)

    # cropped =
    Enum.reduce(
      contours_with_matrix,
      image,
      fn x, img ->
        contour =
          contours
          |> Enum.at(x)

        cond do
          contour == nil ->
            img

          true ->
            contour
            |> That.find_extreme_points()
            |> Evision.convexHull(clockwise: false)
            |> Evision.Mat.to_nx()
            |> Nx.to_list()
            |> Enum.map(fn [x] -> x end)
            |> Enum.sort_by(fn [x, y] -> x * x + y * y end)
            |> draw_points_on_image(img)
        end
      end
    )
  end

  def main() do
    cap = Evision.VideoCapture.videoCapture()
    img = Evision.VideoCapture.retrieve(cap)
    # Evision.Wx.imshow("frame", img)
  end

  def show_video() do
    cap = Evision.VideoCapture.videoCapture(0)
    show_video(cap)
  end

  def show_video(cap) do
    case Evision.VideoCapture.read(cap) do
      %Evision.Mat{} = frame ->
        # as along as you're using the same window title, 
        # the frame will be plotted in the same window

        Evision.Wx.imshow("window title", That.test_decode_matrix(frame))
        show_video(cap)

      _ ->
        # video has ended or an error occurred
        :no_more_frames
    end
  end
z
  def decode_matrix(image, show_image \\ false) do
    # image = Evision.imread(image_path)
    gray = Evision.cvtColor(image, Evision.Constant.cv_COLOR_BGR2GRAY())

    {_, thresholded} =
      gray
      |> Evision.threshold(
        50,
        255,
        Evision.Constant.cv_THRESH_BINARY() ||| Evision.Constant.cv_THRESH_OTSU()
      )

    {contours, heirarchy} =
      Evision.findContours(
        thresholded,
        Evision.Constant.cv_RETR_TREE(),
        Evision.Constant.cv_CHAIN_APPROX_NONE()
      )

    cropped =
      contours
      |> Enum.at(find_contour_containing_matrix(heirarchy))
      |> That.find_extreme_points()
      |> Evision.convexHull(clockwise: false)
      |> Evision.Mat.to_nx()
      |> Nx.to_list()
      |> Enum.map(fn [x] -> x end)
      |> Enum.sort_by(fn [x, y] -> x * x + y * y end)
      |> That.crop_to_points(image)

    if show_image do
      cropped
    else
      [
        [100, 100],
        [300, 100],
        [100, 300],
        [300, 300]
      ]
      |> Enum.map(fn x ->
        cropped[x]
        |> Evision.Mat.at(0) >= 1
      end)
    end
  end
  def test_image() do
    image = Evision.imread("../matrix_detection_input_images/2_skewed.png")
    Evision.Wx.imshow("frame", test_decode_matrix(image))
    Process.sleep(:infinity)
  end
end
