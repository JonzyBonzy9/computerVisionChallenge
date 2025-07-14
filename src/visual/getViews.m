function Views = getViews(app)
Views = struct();
Views.Overlay = OverlayView(app);
Views.Difference = DifferenceView3(app);
%Views.Difference = DifferenceView(app);
%Views.TimeSliderOverlay = TimeSliderOverlayView(app);
%Views.TimeSlider = TimeSliderView(app);
%Views.GridView = GridView(app);
end