defmodule That do
  alias Evision.TonemapDrago
  @green {0, 255, 0, 255}

  @type heirarchy :: list({integer(), integer(), integer(), integer()})

  @doc """
  Takes a list of contours and draws them on the given image.
  """
  @spec draw_contours_on_image(
          Evision.Mat.maybe_mat_in() | [Evision.Mat.maybe_mat_in()],
          Evision.Mat.maybe_mat_in()
        ) ::
          Evision.Mat.maybe_mat_out()
  def draw_contours_on_image(contours, image)
      when is_list(contours) or (is_tuple(contours) and is_struct(image, Evision.Mat)) do
    Evision.drawContours(image, contours, -1, @green, thickness: 2)
  end

  @doc """
  Draw points on image

  Take a list of points (list of 2 element list) and an image, and draws
  the position and the corrdinates on the given image.
  """
  @spec draw_points_on_image(list(integer()), Evision.Mat.maybe_mat_in()) ::
          Evision.Mat.maybe_mat_out()
  def draw_points_on_image(points, image) do
    Enum.reduce(points, image, fn [x, y], img ->
      Evision.circle(img, {x, y}, 1, @green, thickness: 3)
      |> Evision.putText(
        "#{x}, #{y}",
        {x + 10, y},
        Evision.Constant.cv_FONT_HERSHEY_SIMPLEX(),
        0.5,
        @green
      )
    end)
  end

  @doc """
  Returns a list of indices of contours, areas of which lie in between the given range.
  """
  @spec filter_by_area(list(), integer(), integer() | :infinity) :: list()
  def filter_by_area(contours, min_area, max_area) do
    contours
    |> Enum.with_index()
    |> Enum.reject(fn {contour, _} ->
      # |> Enum.reject(fn contour ->
      area = Evision.contourArea(contour)
      area < min_area or area > max_area
    end)
    |> Enum.map(fn {_, i} ->
      i
    end)
  end

  @doc """
  Returns a list of contours which are quadrilaterals.
  """
  @spec find_quads(list(Evision.Mat.maybe_mat_in())) :: list(integer())
  def find_quads(contours) do
    Enum.with_index(contours)
    |> Enum.filter(fn {c, _} ->
      peri = Evision.arcLength(c, true)
      approx = Evision.approxPolyDP(c, 0.01 * peri, true)
      hull = Evision.convexHull(approx, returnPoints: false)

      {_, [size, 1]} = Evision.Mat.size(hull)
      # four sides
      size == 4
    end)
    |> Enum.map(fn {_, idx} ->
      idx
    end)
  end

  #                                 next prev fc    parent
  # Find inner most contours        [x   x    -1    x     ]
  # Check if less than 4 contours 
  # Take the parent contour
  # Check if a quad
  # Get the extreme points  

  @doc """
  Returns the list of indices of contours which have no children.

  OR

  Returns the list of indices of contours which are deepest in the tree.
  """
  @spec find_inner_most_contours(heirarchy) :: heirarchy
  def find_inner_most_contours(heirarchy) do
    Enum.filter(
      Enum.with_index(heirarchy),
      fn
        # No children
        {[_, _, -1, _], _} ->
          true

        _ ->
          false
      end
    )
  end

  @doc """
  Finds the coutours which could contain a matrix
  """
  @spec find_contour_containing_matrix(heirarchy) :: [integer(), ...]
  def find_contour_containing_matrix(heirarchy) do
    find_inner_most_contours(heirarchy)
    |> Enum.map(fn {[_, _, _, x], _} -> x end)
    |> Enum.uniq()
  end

  def find_extreme_points(contour) do
    peri = Evision.arcLength(contour, true)
    Evision.approxPolyDP(contour, 0.02 * peri, true)
  end

  @spec crop_to_points(list(list(integer())), Evision.Mat.maybe_mat_in()) ::
          Evision.Mat.maybe_mat_out()
  def crop_to_points(points, image) do
    pts1 = Evision.Mat.literal(points, :f32)

    pts2 =
      Evision.Mat.literal([[10, 10], [400 - 10, 10], [10, 400 - 10], [400 - 10, 400 - 10]], :f32)

    transform = Evision.perspectiveTransform(pts1, pts2)

    Evision.warpPerspective(image, transform, {410, 410})
  end

  def test_decode_matrix(image, _config) do
    gray = Evision.cvtColor(image, Evision.Constant.cv_COLOR_BGR2GRAY())

    blurred =
      gray
      |> Evision.medianBlur(9)

    thresholded =
      Evision.adaptiveThreshold(
        blurred,
        255,
        Evision.Constant.cv_ADAPTIVE_THRESH_GAUSSIAN_C(),
        Evision.Constant.cv_THRESH_BINARY_INV(),
        101,
        1
      )

    {contours, heirarchy} =
      Evision.findContours(
        thresholded,
        Evision.Constant.cv_RETR_TREE(),
        Evision.Constant.cv_CHAIN_APPROX_NONE()
      )

    contours_with_valid_area = filter_by_area(contours, 2000, 200_000)

    quad_contours =
      contours
      |> find_quads()

    heirarchy =
      heirarchy
      |> Evision.Mat.to_nx(Nx.BinaryBackend)
      |> Nx.to_list()
      |> List.first()

    # TODO: Make this reject none area and none quad indices
    # matrix_containing_contours =
    #   quad_contours
    #   |> Enum.map(fn x -> Enum.at(heirarchy, x) end)
    #   |> find_contour_containing_matrix()

    # final_contours = matrix_containing_contours -- quad_contours
    # IO.puts("Total contours: #{length(contours)}")
    # IO.puts("Valid area contours: #{length(contours_with_valid_area)}")
    # IO.puts("Quad contours : #{length(quad_contours)}")
    # IO.puts("Final contours : #{length(final_contours)}")

    contours_with_valid_area
    |> Enum.map(fn x -> Enum.at(contours, x) end)
    |> draw_contours_on_image(image)
  end

  def show_video(config) do
    cap = Evision.VideoCapture.videoCapture(0)
    show_video(cap, config)
  end

  def show_video(cap, config) do
    # Process.sleep(100)

    case Evision.VideoCapture.read(cap) do
      %Evision.Mat{} = frame ->
        # as along as you're using the same window title, 
        # the frame will be plotted in the same window

        Evision.Wx.imshow("window title", That.test_decode_matrix(frame, config))
        show_video(cap, config)

      _ ->
        # video has ended or an error occurred
        :no_more_frames
        Evision.Wx.destroyWindow("window title")
        Evision.VideoCapture.release(cap)
    end
  end
end
